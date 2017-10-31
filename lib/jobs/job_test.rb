class JobTest
  def self.perform(param1)
    (1..5).each do |n|
      puts "job: #{param1}: #{n}"
      sleep(2)
    end
  end
end
