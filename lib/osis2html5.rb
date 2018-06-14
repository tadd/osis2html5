require 'osis2html5/version'

require 'nokogiri'

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
    doc.css('div[@type="book"]').each do |book|
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

    convert_ruby(book)
    filename = name + '.html'

    path = File.join(ARGV[1], filename)
    File.write(path, book.to_xhtml)
  end
end
