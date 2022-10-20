import collections
import os

import xml.etree.ElementTree as ET


class Embed:

    EmbedContext = collections.namedtuple("EmbedContext", ["count", "html_el"])

    def __init__(self, fail_only=False, combine_tag=None):
        self.fail_only = fail_only
        self.combine_tag = combine_tag
        self._data = None
        self._mime_type = None
        self._caption = None

    def evalDoEmbedArgs(self):
        return (self._mime_type, self._data or "NO DATA", self._caption)


class EmbedData(Embed):
    def __init__(
        self, caption, data, mime_type="text/plain", fail_only=False, combine_tag=None
    ):
        Embed.__init__(self, fail_only=fail_only, combine_tag=combine_tag)
        self._caption = caption
        self._data = data
        self._mime_type = mime_type


class EmbedLink(Embed):
    def __init__(self, caption, data, fail_only=False, combine_tag=None):
        # data must be a list of 2-tuples, where the first element
        # is the link target (href) and the second the text.
        Embed.__init__(self, fail_only=fail_only, combine_tag=combine_tag)

        new_data = []
        for d in data:
            (target, text) = d
            new_data.append((target, text))

        self._caption = caption
        self._data = new_data
        self._mime_type = "link"


class _Embed:
    def __init__(self):
        self.coredump_reported = False
        self._embed_count = 0
        self._to_embed = []

        self.Embed = Embed
        self.EmbedData = EmbedData
        self.EmbedLink = EmbedLink

    def setup(self, runner):
        # setup formatter embed and set_title
        for formatter in runner.formatters:
            if "html" not in formatter.name:
                continue
            if hasattr(formatter, "set_title"):
                self._set_title = formatter.set_title
            if hasattr(formatter, "embedding"):
                self._html_formatter = formatter

    def get_embed_context(self):
        self._embed_count += 1
        count = self._embed_count

        html_el = None
        if hasattr(self, "_html_formatter"):
            html_el = self._html_formatter.actual["act_step_embed_span"]
        return Embed.EmbedContext(count, html_el)

    def set_title(self, *a, **kw):
        if hasattr(self, "_set_title"):
            self._set_title(*a, *kw)

    def _embed_queue(self, entry, embed_context=None):

        if embed_context is None:
            embed_context = self.get_embed_context()

        entry._embed_context = embed_context

        self._to_embed.append(entry)

    def _embed_args(self, html_el, mime_type, data, caption):

        if hasattr(self, "_html_formatter"):
            self._html_formatter._doEmbed(html_el, mime_type, data, caption)
            if mime_type == "link":
                # list() on ElementTree returns children
                last_embed = list(html_el)[-1]
                for a_tag in last_embed.findall("a"):
                    if a_tag.get("href", "").startswith("data:"):
                        a_tag.set("download", a_tag.text)
            ET.SubElement(html_el, "br")

        if os.environ.get("NMCI_SHOW_EMBED") == "1":
            print(f">>>> EMBED[{mime_type}]: {caption}")
            for line in str(data).splitlines():
                print(f">>>>>> {line}")

    def _embed_mangle_message_for_fail(self, scenario_fail, fail_only, mime_type, data):
        if not scenario_fail and fail_only:
            if mime_type != "text/plain":
                return ("text/plain", f"truncated mime_type={mime_type} on success")
            if isinstance(data, str):
                if len(data) > 2048:
                    return (mime_type, "truncated on success\n\n...\n" + data[-2048:])
            elif isinstance(data, bytes):
                if len(data) > 2048:
                    return (
                        mime_type,
                        b"truncated binary on success\n\n...\n" + data[-2048:],
                    )
            else:
                return (mime_type, f"truncated non-text {type(data)} on success")
        return (mime_type, data)

    def _embed_one(self, scenario_fail, entry):
        (mime_type, data, caption) = entry.evalDoEmbedArgs()
        (mime_type, data) = self._embed_mangle_message_for_fail(
            scenario_fail, entry.fail_only, mime_type, data
        )
        self._embed_args(
            entry._embed_context.html_el,
            mime_type,
            data,
            f"({entry._embed_context.count}) {caption}",
        )

    def _embed_combines(self, scenario_fail, combine_tag, html_el, lst):
        counts = ",".join(str(entry._embed_context.count) for entry in lst)
        main_caption = f"({counts}) {combine_tag}"
        message = ""
        for entry in lst:
            (mime_type, data, caption) = entry.evalDoEmbedArgs()
            assert mime_type == "text/plain"
            (mime_type, data) = self._embed_mangle_message_for_fail(
                scenario_fail, entry.fail_only, mime_type, data
            )
            message += f"{'-'*50}\n({entry._embed_context.count}) {caption}\n{data}\n"
        message += f"{'-'*50}\n"
        self._embed_args(html_el, "text/plain", message, main_caption)

    def process_embeds(self, scenario_fail):
        import nmci.util

        combines_dict = {}
        self._to_embed.sort(key=lambda e: e._embed_context.count)
        for entry in nmci.util.consume_list(self._to_embed):
            combine_tag = entry.combine_tag
            if combine_tag is None:
                self._embed_one(scenario_fail, entry)
                continue
            key = (combine_tag, entry._embed_context.html_el)
            lst = combines_dict.get(key, None)
            if lst is None:
                lst = []
                combines_dict[key] = lst
            lst.append(entry)
        for key, lst in combines_dict.items():
            self._embed_combines(scenario_fail, key[0], key[1], lst)

    def embed_data(self, *a, embed_context=None, **kw):
        self._embed_queue(EmbedData(*a, **kw), embed_context=embed_context)

    def embed_link(self, *a, embed_context=None, **kw):
        self._embed_queue(EmbedLink(*a, **kw), embed_context=embed_context)

    def embed_dump(self, caption, dump_id, *, data=None, links=None):
        print("Attaching %s, %s" % (caption, dump_id))
        import nmci.misc

        assert (data is None) + (links is None) == 1
        if data is not None:
            self.embed_data(caption, data)
        else:
            self.embed_link(caption, links)
        self.coredump_reported = True
        nmci.misc.coredump_report(dump_id)

    def embed_run(
        self,
        argv,
        shell,
        returncode,
        stdout,
        stderr,
        fail_only=True,
        embed_context=None,
    ):
        import nmci.util

        if stdout is not None:
            try:
                stdout = nmci.util.bytes_to_str(stdout)
            except UnicodeDecodeError:
                pass
        if stderr is not None:
            try:
                stderr = nmci.util.bytes_to_str(stderr)
            except UnicodeDecodeError:
                pass

        message = f"{repr(argv)} {'(shell) ' if shell else ''}returned {returncode}\n"
        if stdout:
            message += (
                f"STDOUT{'[binary]' if isinstance(stderr, bytes) else ''}:\n{stdout}\n"
            )
        if stderr:
            message += (
                f"STDERR{'[binary]' if isinstance(stderr, bytes) else ''}:\n{stderr}\n"
            )

        if isinstance(argv, bytes):
            title = argv.decode("utf-8", errors="replace")
        elif isinstance(argv, str):
            title = argv
        else:
            import shlex
            import nmci.util

            title = " ".join(
                shlex.quote(nmci.util.bytes_to_str(a, errors="replace")) for a in argv
            )
        if len(argv) < 30:
            title = f"Command `{title}`"
        else:
            title = f"Command `{title[:30]}...`"

        self.embed_data(
            title,
            message,
            fail_only=fail_only,
            combine_tag="Commands",
            embed_context=embed_context,
        )

    def embed_service_log(
        self,
        descr,
        service=None,
        syslog_identifier=None,
        journal_args=None,
        cursor=None,
        fail_only=False,
    ):
        print("embedding " + descr + " logs")
        import nmci.misc

        if cursor is None:
            import nmci

            cursor = nmci.cext.context.log_cursor
        self.embed_data(
            descr,
            nmci.misc.journal_show(
                service=service,
                syslog_identifier=syslog_identifier,
                journal_args=journal_args,
                cursor=cursor,
            ),
            fail_only=fail_only,
        )

    def embed_file_if_exists(
        self,
        caption,
        fname,
        as_base64=False,
        fail_only=False,
    ):
        import nmci.util

        if not os.path.isfile(fname):
            print("Warning: File " + repr(fname) + " not found")
            return False

        if caption is None:
            caption = fname

        print("embeding " + caption + " log (" + fname + ")")

        if not as_base64:
            data = nmci.util.file_get_content_simple(fname)
            self.embed_data(caption, data, fail_only=fail_only)
            return True

        import base64

        data = nmci.util.file_get_content_simple(fname, as_bytes=True)
        data_base64 = base64.b64encode(data)
        data_encoded = data_base64.decode("utf-8").replace("\n", "")
        data = "data:application/octet-stream;base64," + data_encoded

        self.embed_link(caption, [(data, fname)], fail_only=fail_only)
        return True