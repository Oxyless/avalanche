module Avalanche
  class SafeArray
    def initialize
      @datas = Array.new
      @mutex = Mutex.new
    end

    def fetch(&block)
      self.each do |elem|
        return elem if yield(elem) == true
      end

      return nil
    end

    def map(&block)
      map = []

      self.each do |elem|
        map = yield(elem)
      end
      
      map
    end

    def [](idx)
      @datas[idx]
    end

    def <<(elem)
      self.push(elem)
    end

    def push(elem)
      idx = 0

      @mutex.synchronize do
        @datas << elem

        idx = @datas.size - 1
      end

      idx
    end

    def each(&block)
      i = 0
      while @datas[i]
        yield(@datas[i])
        i = i + 1
      end
    end
  end
end
