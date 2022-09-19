import collections
import os
import re
import subprocess

from nmci import util
from nmci import embed


RunResult = collections.namedtuple("RunResult", ["returncode", "stdout", "stderr"])

IGNORE_RETURNCODE_ALL = object()

SHELL_AUTO = object()


class ProcessHook:
    def __init__(self):
        self.actions = {}

    def add_action(self, name, callback):
        assert name not in self.actions
        self.actions[name] = callback

    def _do_action(self, name, *a):
        if name not in self.actions:
            return
        self.actions[name](*a)


process_hook_embed_result = ProcessHook()
process_hook_embed_result.add_action("result", lambda *a: embed.embed_run(*a))


class WithShell:
    def __init__(self, cmd):
        assert isinstance(cmd, str)
        self.cmd = cmd

    def __str__(self):
        return self.cmd


class PopenCollect:
    def __init__(self, proc, argv=None, argv_real=None, shell=None):
        self.proc = proc
        self.argv = argv
        self.argv_real = argv_real
        self.shell = shell
        self.returncode = None
        self.stdout = b""
        self.stderr = b""

    def read_and_poll(self):

        if self.returncode is None:
            c = self.proc.poll()
            if self.proc.stdout is not None:
                self.stdout += self.proc.stdout.read()
            if self.proc.stderr is not None:
                self.stderr += self.proc.stderr.read()
            if c is None:
                return None
            self.returncode = c

        return self.returncode

    def read_and_wait(self, timeout=None):
        from nmci import util

        xtimeout = util.start_timeout(timeout)
        while True:
            c = self.read_and_poll()
            if c is not None:
                return c
            if xtimeout.expired():
                return None
            try:
                self.proc.wait(timeout=0.05)
            except subprocess.TimeoutExpired:
                pass

    def terminate_and_wait(self, timeout_before_kill=5):
        self.proc.terminate()
        if self.read_and_wait(timeout=timeout_before_kill) is not None:
            return
        self.proc.kill()
        self.read_and_wait()


class _Process:
    def __init__(self):
        self.ProcessHook = ProcessHook
        self.WithShell = WithShell
        self.PopenCollect = PopenCollect
        self.RunResult = RunResult
        self.IGNORE_RETURNCODE_ALL = IGNORE_RETURNCODE_ALL
        self.SHELL_AUTO = SHELL_AUTO

    def _run_prepare_args(self, argv, shell, env, env_extra):

        if shell is SHELL_AUTO:
            # Autodetect whether to use a shell.
            if isinstance(argv, WithShell):
                argv = argv.cmd
                shell = True
            else:
                shell = False
        else:
            shell = True if shell else False

        argv_real = argv

        if isinstance(argv_real, str):
            # For convenience, we allow argv as string.
            if shell:
                argv_real = [argv_real]
            else:
                import shlex

                argv_real = shlex.split(argv_real)

        if env_extra:
            if env is None:
                env = dict(os.environ)
            else:
                env = dict(env)
            env.update(env_extra)

        return argv, argv_real, shell, env

    def Popen(
        self,
        argv,
        *,
        shell=SHELL_AUTO,
        cwd=util.BASE_DIR,
        env=None,
        env_extra=None,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        process_hook=process_hook_embed_result,
    ):

        argv, argv_real, shell, env = self._run_prepare_args(
            argv, shell, env, env_extra
        )

        if process_hook is not None:
            process_hook._do_action("popen-call", argv_real, shell)

        proc = subprocess.Popen(
            argv_real,
            shell=shell,
            stdout=stdout,
            stderr=stderr,
            cwd=cwd,
            env=env,
        )

        return PopenCollect(proc, argv=argv, argv_real=argv_real, shell=shell)

    def _run(
        self,
        argv,
        *,
        shell,
        as_bytes,
        timeout,
        cwd,
        env,
        env_extra,
        ignore_stderr,
        ignore_returncode,
        stdout,
        stderr,
        process_hook,
    ):
        argv, argv_real, shell, env = self._run_prepare_args(
            argv, shell, env, env_extra
        )

        if process_hook is not None:
            process_hook._do_action("call", argv_real, shell, timeout)

        proc = subprocess.run(
            argv_real,
            shell=shell,
            stdout=stdout,
            stderr=stderr,
            timeout=timeout,
            cwd=cwd,
            env=env,
        )

        (returncode, r_stdout, r_stderr) = (proc.returncode, proc.stdout, proc.stderr)

        if r_stdout is None:
            r_stdout = b""
        if r_stderr is None:
            r_stderr = b""

        if process_hook is not None:
            process_hook._do_action(
                "result", argv_real, shell, returncode, r_stdout, r_stderr
            )

        # Depending on ignore_returncode we accept non-zero output. But
        # even then we want to fail for return codes that indicate a crash
        # (e.g. 134 for SIGABRT). If you really want to accept *any* return code,
        # set ignore_returncode=nmci.process.IGNORE_RETURNCODE_ALL.
        if (
            returncode == 0
            or (ignore_returncode is IGNORE_RETURNCODE_ALL)
            or (ignore_returncode and returncode > 0 and returncode <= 127)
        ):
            pass
        else:
            raise Exception(
                "`%s` returned exit code %s\nSTDOUT:\n%s\nSTDERR:\n%s"
                % (
                    " ".join(
                        [util.bytes_to_str(s, errors="replace") for s in argv_real]
                    ),
                    returncode,
                    r_stdout.decode("utf-8", errors="replace"),
                    r_stderr.decode("utf-8", errors="replace"),
                )
            )

        if not ignore_stderr and r_stderr:
            # if anything was printed to stderr, we consider that a fail.
            raise Exception(
                "`%s` printed something on stderr\nSTDERR:\n%s"
                % (
                    " ".join(
                        [util.bytes_to_str(s, errors="replace") for s in argv_real]
                    ),
                    r_stderr.decode("utf-8", errors="replace"),
                )
            )

        if not as_bytes:
            try:
                r_stdout = r_stdout.decode("utf-8", errors="strict")
            except UnicodeDecodeError as e:
                raise Exception(
                    "`%s` printed non-utf-8 to stdout\nSTDOUT:\n%s"
                    % (
                        " ".join(
                            [util.bytes_to_str(s, errors="replace") for s in argv_real]
                        ),
                        r_stdout.decode("utf-8", errors="replace"),
                    )
                )
            try:
                r_stderr = r_stderr.decode("utf-8", errors="strict")
            except UnicodeDecodeError as e:
                raise Exception(
                    "`%s` printed non-utf-8 to stderr\nSTDERR:\n%s"
                    % (
                        " ".join(
                            [util.bytes_to_str(s, errors="replace") for s in argv_real]
                        ),
                        r_stderr.decode("utf-8", errors="replace"),
                    )
                )

        return RunResult(returncode, r_stdout, r_stderr)

    def run(
        self,
        argv,
        *,
        shell=SHELL_AUTO,
        as_bytes=False,
        timeout=5,
        cwd=util.BASE_DIR,
        env=None,
        env_extra=None,
        ignore_returncode=True,
        ignore_stderr=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        process_hook=process_hook_embed_result,
    ):
        return self._run(
            argv,
            shell=shell,
            as_bytes=as_bytes,
            timeout=timeout,
            cwd=cwd,
            env=env,
            env_extra=env_extra,
            ignore_stderr=ignore_stderr,
            ignore_returncode=ignore_returncode,
            stdout=stdout,
            stderr=stderr,
            process_hook=process_hook,
        )

    def run_stdout(
        self,
        argv,
        *,
        shell=SHELL_AUTO,
        as_bytes=False,
        timeout=5,
        cwd=util.BASE_DIR,
        env=None,
        env_extra=None,
        ignore_returncode=False,
        ignore_stderr=False,
        stderr=subprocess.PIPE,
        process_hook=process_hook_embed_result,
    ):
        return self._run(
            argv,
            shell=shell,
            as_bytes=as_bytes,
            timeout=timeout,
            cwd=cwd,
            env=env,
            env_extra=env_extra,
            ignore_stderr=ignore_stderr,
            ignore_returncode=ignore_returncode,
            stdout=subprocess.PIPE,
            stderr=stderr,
            process_hook=process_hook,
        ).stdout

    def run_code(
        self,
        argv,
        *,
        shell=SHELL_AUTO,
        as_bytes=False,
        timeout=5,
        cwd=util.BASE_DIR,
        env=None,
        env_extra=None,
        ignore_returncode=True,
        ignore_stderr=False,
        process_hook=process_hook_embed_result,
    ):
        return self._run(
            argv,
            shell=shell,
            as_bytes=as_bytes,
            timeout=timeout,
            cwd=cwd,
            env=env,
            env_extra=env_extra,
            ignore_stderr=ignore_stderr,
            ignore_returncode=ignore_returncode,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            process_hook=process_hook,
        ).returncode

    def run_search_stdout(
        self,
        argv,
        pattern,
        *,
        shell=SHELL_AUTO,
        timeout=5,
        cwd=util.BASE_DIR,
        env=None,
        env_extra=None,
        ignore_returncode=False,
        ignore_stderr=False,
        stderr=subprocess.PIPE,
        pattern_flags=re.DOTALL | re.MULTILINE,
        process_hook=process_hook_embed_result,
    ):
        # autodetect based on the pattern
        if isinstance(pattern, bytes):
            as_bytes = True
        elif isinstance(pattern, str):
            as_bytes = False
        else:
            as_bytes = isinstance(pattern.pattern, bytes)
        result = self._run(
            argv,
            shell=shell,
            as_bytes=as_bytes,
            timeout=timeout,
            cwd=cwd,
            env=env,
            env_extra=env_extra,
            ignore_stderr=ignore_stderr,
            ignore_returncode=ignore_returncode,
            stdout=subprocess.PIPE,
            stderr=stderr,
            process_hook=process_hook,
        )
        return re.search(pattern, result.stdout, flags=pattern_flags)

    def nmcli(
        self,
        argv,
        *,
        as_bytes=False,
        timeout=60,
        cwd=util.BASE_DIR,
        env=None,
        env_extra=None,
        ignore_returncode=False,
        ignore_stderr=False,
        process_hook=process_hook_embed_result,
    ):
        if isinstance(argv, str):
            argv = f"nmcli {argv}"
        else:
            argv = ["nmcli", *argv]

        return self._run(
            argv,
            shell=False,
            as_bytes=as_bytes,
            timeout=timeout,
            cwd=cwd,
            env=env,
            env_extra=env_extra,
            ignore_stderr=ignore_stderr,
            ignore_returncode=ignore_returncode,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            process_hook=process_hook,
        ).stdout

    def nmcli_force(
        self,
        argv,
        *,
        as_bytes=False,
        timeout=60,
        cwd=util.BASE_DIR,
        env=None,
        env_extra=None,
        ignore_returncode=True,
        ignore_stderr=True,
        process_hook=process_hook_embed_result,
    ):
        if isinstance(argv, str):
            argv = f"nmcli {argv}"
        else:
            argv = ["nmcli", *argv]

        return self._run(
            argv,
            shell=False,
            as_bytes=as_bytes,
            timeout=timeout,
            cwd=cwd,
            env=env,
            env_extra=env_extra,
            ignore_stderr=ignore_stderr,
            ignore_returncode=ignore_returncode,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            process_hook=process_hook,
        )

    def systemctl(
        self,
        argv,
        *,
        as_bytes=False,
        timeout=60,
        cwd=util.BASE_DIR,
        env=None,
        env_extra=None,
        ignore_returncode=True,
        ignore_stderr=True,
        process_hook=process_hook_embed_result,
    ):
        if isinstance(argv, str):
            argv = f"systemctl {argv}"
        else:
            argv = ["systemctl", *argv]

        return self._run(
            argv,
            shell=False,
            as_bytes=as_bytes,
            timeout=timeout,
            cwd=cwd,
            env=env,
            env_extra=env_extra,
            ignore_stderr=ignore_stderr,
            ignore_returncode=ignore_returncode,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            process_hook=process_hook,
        )
