import os
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
FALLBACK_PANDOC = r"C:\Users\truon\tools\pandoc-3.12.1\pandoc.exe"
DEFAULT_INPUTS = ["week1.md", "week2.md", "week3.md", "week4.md"]
DEFAULT_OUTPUT = "BaoCao_Prometheus_Grafana_AWS.docx"

UNBOLD_FILTER = """
function Strong(el)
  return el.content
end
"""

TABLE_BORDERS = (
    "<w:tblBorders>"
    + "".join(
        f'<w:{side} w:val="single" w:sz="4" w:space="0" w:color="000000"/>'
        for side in ("top", "left", "bottom", "right", "insideH", "insideV")
    )
    + "</w:tblBorders>"
)

CODE_FONT = '<w:rFonts w:ascii="Consolas" w:hAnsi="Consolas" w:cs="Consolas" w:eastAsia="Consolas"/>'

SOURCE_CODE_STYLE = (
    '<w:style w:type="paragraph" w:customStyle="1" w:styleId="SourceCode">'
    '<w:name w:val="Source Code"/><w:basedOn w:val="Normal"/><w:qFormat/>'
    "<w:pPr>"
    "<w:keepLines/>"
    "<w:pBdr>"
    + "".join(
        f'<w:{side} w:val="single" w:sz="4" w:space="4" w:color="BFBFBF"/>'
        for side in ("top", "left", "bottom", "right")
    )
    + "</w:pBdr>"
    '<w:shd w:val="clear" w:color="auto" w:fill="F2F2F2"/>'
    '<w:spacing w:before="120" w:after="120" w:line="240" w:lineRule="auto"/>'
    '<w:ind w:left="113" w:right="113" w:firstLine="0"/>'
    '<w:jc w:val="left"/>'
    "</w:pPr>"
    f'<w:rPr>{CODE_FONT}<w:color w:val="000000"/><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr>'
    "</w:style>"
)

VERBATIM_CHAR_STYLE = (
    '<w:style w:type="character" w:customStyle="1" w:styleId="VerbatimChar">'
    '<w:name w:val="Verbatim Char"/><w:basedOn w:val="DefaultParagraphFont"/>'
    f'<w:rPr>{CODE_FONT}<w:color w:val="000000"/><w:sz w:val="20"/><w:szCs w:val="20"/>'
    '<w:shd w:val="clear" w:color="auto" w:fill="F2F2F2"/></w:rPr>'
    "</w:style>"
)


def find_pandoc():
    found = shutil.which("pandoc")
    if found:
        return found
    if os.path.exists(FALLBACK_PANDOC):
        return FALLBACK_PANDOC
    sys.exit("pandoc not found")


def rewrite_zip(path, edits):
    tmp = path + ".tmp"
    with zipfile.ZipFile(path) as src, zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as dst:
        for item in src.infolist():
            data = src.read(item.filename)
            if item.filename in edits:
                data = edits[item.filename](data.decode("utf-8")).encode("utf-8")
            dst.writestr(item, data)
    os.replace(tmp, path)


def style_block(xml, style_id, fn):
    pattern = re.compile(r'(<w:style [^>]*w:styleId="%s".*?</w:style>)' % style_id, re.S)
    return pattern.sub(lambda m: fn(m.group(1)), xml)


def black_bold(block):
    block = re.sub(r"<w:color [^>]*/>", "", block)
    block = re.sub(r"<w:b\s*/>|<w:bCs\s*/>", "", block)
    if "<w:rPr>" not in block:
        return block.replace("</w:style>", '<w:rPr><w:b/><w:bCs/><w:color w:val="000000"/></w:rPr></w:style>')
    head, rpr = block.split("<w:rPr>", 1)
    rpr, tail = rpr.split("</w:rPr>", 1)
    fonts = re.search(r"<w:rFonts [^>]*/>", rpr)
    if fonts:
        rpr = rpr[:fonts.end()] + "<w:b/><w:bCs/>" + rpr[fonts.end():]
    else:
        rpr = "<w:b/><w:bCs/>" + rpr
    size = rpr.find("<w:sz ")
    color = '<w:color w:val="000000"/>'
    rpr = rpr[:size] + color + rpr[size:] if size >= 0 else rpr + color
    return head + "<w:rPr>" + rpr + "</w:rPr>" + tail


def solid_table(block):
    block = re.sub(r"<w:tblBorders>.*?</w:tblBorders>", "", block, flags=re.S)
    return block.replace("<w:tblPr>", "<w:tblPr>" + TABLE_BORDERS, 1)


def edit_styles(xml):
    for sid in ["Title", "Subtitle", "TOCHeading"] + [f"Heading{i}" for i in range(1, 10)]:
        xml = style_block(xml, sid, black_bold)
    return style_block(xml, "Table", solid_table)


def replace_style(xml, style_id, new_block):
    pattern = re.compile(r'<w:style [^>]*w:styleId="%s".*?</w:style>' % style_id, re.S)
    xml = pattern.sub("", xml)
    return xml.replace("</w:styles>", new_block + "</w:styles>")


def edit_output_styles(xml):
    xml = replace_style(xml, "SourceCode", SOURCE_CODE_STYLE)
    return replace_style(xml, "VerbatimChar", VERBATIM_CHAR_STYLE)


def edit_numbering(xml):
    def fix_level(m):
        lvl = m.group(0)
        if 'w:numFmt w:val="bullet"' not in lvl:
            return lvl
        lvl = re.sub(r'<w:lvlText w:val="[^"]*"\s*/>', '<w:lvlText w:val="-"/>', lvl)
        return re.sub(r"<w:rPr>.*?</w:rPr>", "", lvl, flags=re.S)
    return re.sub(r"<w:lvl .*?</w:lvl>", fix_level, xml, flags=re.S)


def main():
    inputs = sys.argv[1:-1] if len(sys.argv) > 2 else DEFAULT_INPUTS
    output = sys.argv[-1] if len(sys.argv) > 2 else DEFAULT_OUTPUT
    if len(sys.argv) == 2:
        inputs, output = [sys.argv[1]], os.path.splitext(sys.argv[1])[0] + ".docx"

    pandoc = find_pandoc()
    with tempfile.TemporaryDirectory() as tmp:
        reference = os.path.join(tmp, "reference.docx")
        lua = os.path.join(tmp, "unbold.lua")
        with open(reference, "wb") as f:
            f.write(subprocess.run([pandoc, "--print-default-data-file", "reference.docx"],
                                   check=True, capture_output=True).stdout)
        rewrite_zip(reference, {"word/styles.xml": edit_styles})
        with open(lua, "w", encoding="utf-8") as f:
            f.write(UNBOLD_FILTER)

        result = subprocess.run(
            [pandoc, *inputs,
             "-f", "markdown+lists_without_preceding_blankline+hard_line_breaks-implicit_figures",
             "-o", output,
             "--syntax-highlighting=none",
             "--toc", "--toc-depth=2",
             "--resource-path", os.pathsep.join([".", ".."]),
             "--reference-doc", reference,
             "--lua-filter", lua],
            cwd=HERE, capture_output=True, text=True, encoding="utf-8")
        if result.returncode != 0:
            sys.exit(result.stderr)

    out_path = os.path.join(HERE, output)
    rewrite_zip(out_path, {"word/numbering.xml": edit_numbering, "word/styles.xml": edit_output_styles})
    missing = sorted(set(re.findall(r"Could not fetch resource ([^\s:]+)", result.stderr)))
    print(f"written {out_path}")
    if missing:
        print(f"{len(missing)} image(s) not found yet:")
        for m in missing:
            print(f"  {m}")


if __name__ == "__main__":
    main()
