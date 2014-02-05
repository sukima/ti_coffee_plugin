class MockLogger
  constructor: -> @buffer = ""
  for fn in ["debug","info","warn","error"]
    @::[fn] = (s) -> @buffer += "#{s}\n"

module.exports = MockLogger
