class Salutation
  def hello(name)
    "hello #{name}"
  end

  def self.hello(name)
    "hi #{name}"
  end

  def hi(first_name, last_name:)
    "hi #{first_name} #{last_name}"
  end

  def self.hi(first_name:, last_name:)
    "hi #{first_name} #{last_name}"
  end
end
