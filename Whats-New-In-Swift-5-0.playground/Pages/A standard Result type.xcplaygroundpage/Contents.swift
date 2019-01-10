/*:
 [< Previous](@previous)           [Home](Introduction)           [Next >](@next)

 ## A standard Result type

 [SE-0235](https://github.com/apple/swift-evolution/blob/master/proposals/0235-add-result.md) introduces a `Result` type into the standard library, giving us a simpler, clearer way of handling errors in complex code such as asynchronous APIs.

 Swift’s `Result` type is implemented as an enum that has two cases: `success` and `failure`. Both are implemented using generics so they can have an associated value of your choosing, but `failure` must be something that conforms to Swift’s `Error` type.

 To demonstrate `Result`, we could write a function that connects to a server to figure out how many unread messages are waiting for the user. In this example code we’re going to have just one possible error, which is that the requested URL string isn’t a valid URL:
*/
enum NetworkError: Error {
    case badURL
}
/*:
 The fetching function will accept a URL string as its first parameter, and a completion handler as its second parameter. That completion handler will itself accept a `Result`, where the success case will store an integer, and the failure case will be some sort of `NetworkError`. We’re not actually going to connect to a server here, but using a completion handler at least lets us simulate asynchronous code.

 Here’s the code:
*/
import Foundation

func fetchUnreadCount1(from urlString: String, completionHandler: @escaping (Result<Int, NetworkError>) -> Void)  {
    guard let url = URL(string: urlString) else {
        completionHandler(.failure(.badURL))
        return
    }

    // complicated networking code here
    print("Fetching \(url.absoluteString)...")
    completionHandler(.success(5))
}
/*:
 To use that code we need to check the value inside our `Result` to see whether our call succeeded or failed, like this:
*/
fetchUnreadCount1(from: "https://www.hackingwithswift.com") { result in
    switch result {
    case .success(let count):
        print("\(count) unread messages.")
    case .failure(let error):
        print(error.localizedDescription)
    }
}
/*:
 There are three more things you ought to know before you start using `Result` in your own code.

 First, `Result` has a `get()` method that either returns the successful value if it exists, or throws its error otherwise. This allows you to convert `Result` into a regular throwing call, like this:
*/
fetchUnreadCount1(from: "https://www.hackingwithswift.com") { result in
    if let count = try? result.get() {
        print("\(count) unread messages.")
    }
}
/*:
 Second, `Result` has an initializer that accepts a throwing closure: if the closure returns a value successfully that gets used for the `success` case, otherwise the thrown error is  placed into the `failure` case.

 For example:
*/
let result = Result { try String(contentsOfFile: someFile) }
/*:
 Third, rather than using a specific error enum that you’ve created, you can also use the general `Error` protocol. In fact, the Swift Evolution proposal says “it's expected that most uses of Result will use `Swift.Error` as the `Error` type argument.”

 So, rather than using `Result<Int, NetworkError>` you could use `Result<Int, Error>`. Although this means you lose the safety of typed throws, you gain the ability to throw a variety of different error enums – which you prefer really depends on your coding style.

 
  ## Transforming Result

 `Result` has four other methods that may prove useful: `map()`, `flatMap()`, `mapError()`, and `flatMapError()`. Each of these give you the ability to transform either the success or error somehow, and the first two work similarly to the methods of the same name on `Optional`.

 The `map()` method looks inside the `Result`, and transforms the success value into a different kind of value using a closure you specify. However, if it finds failure instead, it just uses that directly and ignores your transformation.

 To demonstrate this, we’re going to write some code that generates random numbers between 0 and a maximum then calculate the factors of that number. If the user requests a random number below zero, or if the number happens to be prime – i.e., it has no factors except itself and 1 – then we’ll consider those to be failures.

 We might start by writing code to model the two possible failure cases: the user has tried to generate a random number below 0, and the number that was generated was prime:
*/
enum FactorError: Error {
    case belowMinimum
    case isPrime
}
/*:
 Next, we’d write a function that accepts a maximum number, and returns either a random number or an error:
*/
func generateRandomNumber(maximum: Int) -> Result<Int, FactorError> {
    if maximum < 0 {
        // creating a range below 0 will crash, so refuse
        return .failure(.belowMinimum)
    } else {
        let number = Int.random(in: 0...maximum)
        return .success(number)
    }
}
/*
 When that’s called, the `Result` we get back will either be an integer or an error, so we could use `map()` to transform it:
*/
 let result1 = generateRandomNumber(maximum: 11)
 let stringNumber = result1.map { "The random number is: \($0)." }
/*:
 As we’ve passed in a valid maximum number, `result` will be a success with a random number. So, using `map()` will take that random number, use it with our string interpolation, then return another `Result` type, this time of the type `Result<String, FactorError>`.

 However, if we had used `generateRandomNumber(maximum: -11)` then `result` would be set to the failure case with `FactorError.belowMinimum`. So, using `map()` would still return a `Result<String, FactorError>`, but it would have the same failure case and same `FactorError.belowMinimum` error.

 Now that you’ve seen how `map()` lets us transform the success type to another type, let’s continue: we have a random number, so the next step is to calculate the factors for it. To do this, we’ll write another function that accepts a number and calculates its factors. If it finds the number is prime it will send back a failure `Result` with the `isPrime` error, otherwise it will send back the number of factors.

 Here’s that in code:
*/
func calculateFactors(for number: Int) -> Result<Int, FactorError> {
    let factors = (1...number).filter { number % $0 == 0 }

    if factors.count == 2 {
        return .failure(.isPrime)
    } else {
        return .success(factors.count)
    }
}
/*:
 If we wanted to use `map()` to transform the output of `generateRandomNumber()` using `calculateFactors()`, it would look like this:
*/
let result2 = generateRandomNumber(maximum: 10)
let mapResult = result2.map { calculateFactors(for: $0) }
/*:
 However, that make `mapResult` a rather ugly type: `Result<Result<Int, FactorError>, FactorError>`. It’s a `Result` inside another `Result`.

 Just like with optionals, this is where the `flatMap()` method comes in. If your transform closure returns a `Result`, `flatMap()` will return the new `Result` directly rather than wrapping it in another `Result`:
*/
let flatMapResult = result2.flatMap { calculateFactors(for: $0) }
/*:
 So, where `mapResult` was a `Result<Result<Int, FactorError>, FactorError>`, `flatMapResult` is flattened down into `Result<Int, FactorError>` – the first original success value (a random number) was transformed into a new success value (the number of factors). Just like `map()`, if either `Result` was a failure, `flatMapResult` will also be a failure.

 As for `mapError()` and `flatMapError()`, those do similar things except they transform the *error* value rather than the *success* value.

 &nbsp;

 [< Previous](@previous)           [Home](Introduction)           [Next >](@next)
 */
