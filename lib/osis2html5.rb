require_relative 'osis2html5/version'

require 'optparse'
require 'nokogiri'
require 'parallel'

module Osis2Html5
  SUMMARY_NCHAR = 140

  module_function

  def run
    opts = {}
    OptionParser.new do |o|
      o.banner = "usage: osis2html5 [options] <input.osis> <output dirname>"

      o.on('-v', '--version', 'show version') do
        puts "osis2html5 #{VERSION}"
        exit
      end

      o.on('-h', '--help', 'prints this help') do
        puts o
        exit
      end

      o.on('--erb', 'enable erb mode') do
        opts[:erb] = true
      end
    end.parse!

    main(*ARGV, **opts)
  end

  def header(message)
    STDERR.puts message
  end

  def main(osis, outdir, **opts)
    Dir.mkdir(outdir) rescue nil # just ignore created dir

    header 'parsing OSIS'
    doc = Nokogiri::XML.parse(File.read(osis))

    header 'processing each books'
    Parallel.each(doc.css('div[@type="book"]')) do |book|
      process_book(book, outdir, erb: opts[:erb])
    end

    generate_index(doc, outdir, erb: opts[:erb])
    header '... done!'
  end

  def convert_ruby(doc, rp: true)
    ws = doc.css('w')
    ws.wrap '<ruby/>'
    ws.each do |w|
      rb, rt = w.text, w[:gloss]
      ruby = w.parent
      ruby.content = rb
      if rp
        ruby << "<rp>（</rp><rt>#{rt}</rt><rp>）</rp>"
      else
        ruby << "<rt>#{rt}</rt>"
      end
    end
    doc
  end

  def process_book(book, outdir, erb: false)
    name = book[:osisID].downcase
    print name + ' '

    book.name = 'main'
    book[:class] ='book container'
    book.remove_attribute('type')
    book.remove_attribute('osisID')

    summary = body_text(book)[0, SUMMARY_NCHAR-2] + '……'

    title = book.at_css('title')
    title.name = 'h1'
    title.remove_attribute('type')

    convert_ruby(book)
    convert_chapters(book)
    filename = name + '.html'
    filename << '.erb' if erb

    path = File.join(outdir, filename)
    File.write(path, format_as_whole_doc(book, title.content, summary, erb: erb))
  end

  def body_text(book)
    nodes = book.dup
    nodes.css('title').remove
    nodes.text.gsub(/\n+/, '')
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
      inner_id = osis_id_to_inner_id(chapter[:osisID])
      chapter[:id] = inner_id
      chapter.remove_attribute('osisID')
      title = chapter.at_css('title')
      title.name = 'h2'
      title[:class] = 'chapter-title'
      title.remove_attribute('type')
      title.children.wrap(%(<a href="##{inner_id}">))

      convert_verses(chapter)
      convert_linegroups(chapter)
    end
  end

  def format_verse_number(number, id)
    %(<span class="verse-number"><a href="##{id}">#{number}</a></span>)
  end

  def convert_verses(book)
    book.css('verse').each do |verse|
      verse.name = 'span'
      verse[:class] = 'verse'

      if verse.key?('eID')
        verse['data-e-id'] = osis_id_to_inner_id(verse['eID'])
        verse.remove_attribute('eID')
        next
      end

      osis_id = verse[:osisID]
      inner_id = osis_id_to_inner_id(osis_id)
      verse[:id] = inner_id
      verse.children = %(<span class="verse-content">#{verse.inner_html}</span>)

      verse_number = osis_id_to_verse_number(osis_id)
      formatted = format_verse_number(verse_number, inner_id)
      if verse.child
        verse.child.previous = formatted
      else
        verse.next_sibling.previous = formatted
      end
      verse.remove_attribute('osisID')

      if verse.key?('sID')
        verse['data-s-id'] = osis_id_to_inner_id(verse['sID'])
        verse.remove_attribute('sID')
      end
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

  def format_as_whole_doc(book, title, summary, erb: false)
    xml_header +
      html5_header(title, summary, lang: book.lang, erb: erb) +
      book.to_xml +
      html5_footer
  end

  def embed_variable(name)
    "<%= #{name} if binding.local_variable_defined?(:#{name}) %>"
  end

  def xml_header
    %(<?xml version="1.0" encoding="UTF-8"?>\n)
  end

  def html5_header(title, summary, lang: 'ja', erb: false)
    lang_attrs = %( xml:lang="#{lang}" lang="#{lang}") if lang
    <<~EOS
    <!DOCTYPE html>
    <html xmlns="http://www.w3.org/1999/xhtml"#{lang_attrs}>
    <head>
    <meta charset="UTF-8"/>
    #{embed_variable(:head) if erb}
    <meta property="og:title" content="#{title}"/>
    <meta property="og:type" content="website"/>
    <meta property="og:description" content="#{summary}"/>
    <title>#{title}#{embed_variable(:additional_title) if erb}</title>
    </head>
    <body>
    #{embed_variable(:head_of_body) if erb}
    EOS
  end

  def html5_footer
    <<~EOS
    </body>
    </html>
    EOS
  end

  def generate_index(doc, outdir, erb: false)
    ver = version(doc)
    index = <<~EOS
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE html>
    <html xmlns="http://www.w3.org/1999/xhtml" xml:lang="ja" lang="ja">
    <head>
    <meta charset="UTF-8"/>
    #{embed_variable(:head) if erb}
    <title>#{ver}#{embed_variable(:additional_title) if erb}</title>
    </head>
    <body>
    #{embed_variable(:head_of_body) if erb}
    <main class="container">
    <h1>#{ver}</h1>
    #{book_list(doc).chomp}
    </main>
    </body>
    </html>
    EOS
    filename = 'index.html'
    filename << '.erb' if erb
    path = File.join(outdir, filename)
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
      %(<li><a href="#{id}.html">#{name}</a></li>)
    end

    <<~EOS
    <h2>#{title}</h2>
    <ul>
    #{lis.join("\n")}
    </ul>
    EOS
  end
end
