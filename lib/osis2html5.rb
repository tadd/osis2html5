require_relative 'osis2html5/version'

require 'nokogiri'
require 'parallel'

module Osis2Html5
  module_function

  def run(*argv)
    usage(error: false) if argv.size == 0
    usage(error: true) unless argv.size == 2
    main(*argv)
  end

  def usage(error:)
    out = error ? STDERR : STDOUT
    out.puts "usage: osis2html5 <input.osis> <output dirname>"
    exit(!error)
  end

  def header(message)
    STDERR.puts message
  end

  def main(osis, outdir)
    Dir.mkdir(outdir) rescue nil # just ignore created dir

    header 'parsing OSIS'
    doc = Nokogiri::XML.parse(File.read(osis))

    header 'processing each books'
    Parallel.each(doc.css('div[@type="book"]')) do |book|
      process_book(book, outdir)
    end

    generate_index(doc, outdir)
    header '... done!'
  end

  def convert_ruby(doc)
    ws = doc.css('w')
    ws.wrap '<ruby/>'
    ws.each do |w|
      rb, rt = w.text, w[:gloss]
      ruby = w.parent
      ruby.content = rb
      ruby << "<rt>#{rt}</rt>"
    end
    doc
  end

  def process_book(book, outdir)
    name = book[:osisID].downcase
    header name

    book[:class] = 'book'
    book.remove_attribute('type')
    book.remove_attribute('osisID')

    title = book.at_css('title')
    title.name = 'h1'
    title.remove_attribute('type')

    convert_ruby(book)
    convert_chapters(book)
    filename = name + '.html'

    path = File.join(outdir, filename)
    File.write(path, format_as_whole_doc(book, title.content))
  end

  def osis_id_to_inner_id(osis_id)
    osis_id.sub(/^[^\.]+\./, '').sub('.', ':')
  end

  def osis_id_to_verse_number(osis_id)
    osis_id.sub(/^.*\./, '')
  end

  def convert_chapters(book)
    book.css('chapter').each do |chapter|
      chapter.name = 'div'
      chapter[:id] = osis_id_to_inner_id(chapter[:osisID])
      chapter.remove_attribute('osisID')
      title = chapter.at_css('title')
      title.name = 'h2'
      title[:class] = 'chapter-name'
      title.remove_attribute('type')

      convert_verses(chapter)
      convert_linegroups(chapter)
    end
  end

  def format_verse_number(number, id)
    %(<a href="##{id}"><sup class="verse-number">#{number}</sup></a>)
  end

  def convert_verses(book)
    book.css('verse').each do |verse|
      if verse[:osisID].nil? # TODO: better HTML
        verse.remove
        next
      end
      verse.name = 'span'
      verse[:class] = 'verse'
      osis_id = verse[:osisID]
      inner_id = osis_id_to_inner_id(osis_id)
      verse[:id] = inner_id
      verse.child&.previous = format_verse_number(osis_id_to_verse_number(osis_id), inner_id)
      verse.remove_attribute('osisID')
      verse.remove_attribute('sID') # TODO: better HTML
      verse.remove_attribute('eID') # ditto
    end
  end

  def convert_linegroups(book, insert_br: true)
    book.css('lg').each do |lg|
      lg.name = 'span'
      lg[:class] = 'lg'
      lg.at_css('l').previous = '<br/>' if insert_br
      lg.css('l').each do |l|
        l.name = 'span'
        l[:class] = 'l'
        l << '<br/>' if insert_br
      end
    end
  end

  def format_as_whole_doc(book, title)
    xml_header + html5_header(title) + book.to_xml + html5_footer
  end

  def xml_header
    %(<?xml version="1.0" encoding="UTF-8"?>\n)
  end

  def html5_header(title, lang: 'ja')
    lang_attrs = %( xml:lang="#{lang}" lang="#{lang}") if lang
    <<~EOS
    <!DOCTYPE html>
    <html xmlns="http://www.w3.org/1999/xhtml"#{lang_attrs}>
    <head>
    <meta charset="UTF-8"/>
    <title>#{title}</title>
    </head>
    <body>
    EOS
  end

  def html5_footer
    <<~EOS
    </body>
    </html>
    EOS
  end

  def generate_index(doc, outdir)
    ver = version(doc)
    index = <<-EOS
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="ja" lang="ja">
<head>
<meta charset="UTF-8"/>
<title>#{ver}</title>
</head>
<body>
<div class="container">
<h1>#{ver}</h1>
#{book_list(doc)}
</div>
</body>
</html>
    EOS
    path = File.join(outdir, 'index.html')
    File.write(path, index)
  end

  def version(doc)
    doc.at_css('work title').content
  end

  def book_tables(doc)
    nnew = 27 # yes we know it
    pairs = doc.css('div[@type="book"]').map do |book|
      [book[:osisID].downcase, book.at_css('title[@type="main"]').content]
    end
    if pairs[0][0] == 'matt' # need to reorder
      pairs = pairs[nnew..-1] + pairs[0...nnew]
    end
    nold = pairs.size - nnew
    [pairs[0...nold], pairs[nold..-1]]
  end

  def book_list(doc)
    tables = book_tables(doc)
    book_list_of_testament('旧約聖書', tables[0]) +
      book_list_of_testament('新約聖書', tables[1])
  end

  def book_list_of_testament(title, table)
    lis = table.map do |id, name|
      "<li><a href=#{id}.html>#{name}</a></li>"
    end

    <<~EOS
    <h2>#{title}</h2>
    <ul>
    #{lis.join("\n")}
    </ul>
    EOS
end
end
