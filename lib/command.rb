#!/usr/bin/env ruby
# callowaylc@gmail.com
# Executes bash command and streams result to stdout

def command bash
  IO.popen bash do | io |
    while (char = io.getc) do
      print char
    end
  end
end
