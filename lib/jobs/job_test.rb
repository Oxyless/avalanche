class JobTest
  def self.perform
    (1..100).each do |n|
      puts "job: #{n}"
      sleep(2)
    end

    a + 1
  end
end
