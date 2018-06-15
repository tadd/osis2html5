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
      process_book(book)
    end

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

  def process_book(book)
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

    path = File.join(ARGV[1], filename)
    File.write(path, format_as_whole_doc(book, title.content))
  end

  def osis_id_to_inner_id(osis_id)
    osis_id.sub(/^[^\.]+\./, '').sub('.', ':')
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

  def convert_verses(book)
    book.css('verse').each do |verse|
      if verse[:osisID].nil? # TODO: better HTML
        verse.remove
        next
      end
      verse.name = 'span'
      verse[:class] = 'verse'
      verse[:id] = osis_id_to_inner_id(verse[:osisID])
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

  def html5_header(title)
    <<~EOS
    <!DOCTYPE html>
    <html xmlns="http://www.w3.org/1999/xhtml" xml:lang="ja" lang="ja">
    <head>
    <meta charset="UTF-8">
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
end
