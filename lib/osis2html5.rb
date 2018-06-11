require "osis2html5/version"

module Osis2Html5
  module_function
  def run(*argv)
    usage(error: false) if argv.size == 0
    usage(error: true) unless argv.size == 2
  end

  def usage(error:)
    out = error ? STDERR : STDOUT
    out.puts "usage: osis2html5 <input.osis> <output dirname>"
    exit(!error)
  end
end
