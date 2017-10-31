class JobTest
  def self.perform(param1)
    (1..20).each do |n|
      puts "job: #{param1}: #{n}"
      sleep(2)
    end
  end
end
