do ->
  Q = require("q")
  Q.longStackSupport = true

notText = (isNot) -> if isNot then " not" else ""

toBeAPromise = ->
  missingText = ""
  @message = => "Expected #{jasmine.pp @actual} to#{notText(@isNot)} be a promise object#{missingText}"
  return false unless @actual?
  missing = []
  # Duck typing
  for method in ["then", "fail", "progress", "isFulfilled", "isRejected", "isPending", "inspect"]
    missing.push method unless @actual[method]?
  missingText = " (missing: #{missing.join(", ")})" if not @isNot and missing.length > 0
  missing.length is 0

toBeFulfilled = ->
  @message = => "Expected promise #{jasmine.pp @actual.inspect()} to#{notText(@isNot)} be fulfilled"
  @actual.isFulfilled()

toBeFulfilledWith = (expected) ->
  @message = => "Expected promise #{jasmine.pp @actual.inspect()} to#{notText(@isNot)} be fulfilled with #{jasmine.pp expected}"
  @actual.isFulfilled() and jasmine.getEnv().equals_(@actual.inspect().value, expected)

toBeRejected = ->
  @message = => "Expected promise #{jasmine.pp @actual.inspect()} to#{notText(@isNot)} be rejected"
  @actual.isRejected()

toBeRejectedWith = (expected) ->
  @message = => "Expected promise #{jasmine.pp @actual.inspect()} to#{notText(@isNot)} be rejected with #{jasmine.pp expected}"
  @actual.isRejected() and jasmine.getEnv().equals_(@actual.inspect().reason, expected)

toBePending = ->
  @message = => "Expected promise to#{notText(@isNot)} be pending"
  @actual.isPending()

beforeEach ->
  @addMatchers {
    toBeAPromise
    toBeFulfilled
    toBeFulfilledWith
    toBeRejected
    toBeRejectedWith
    toBePending
  }
