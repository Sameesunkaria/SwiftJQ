# SwiftJQ - A Swift interface for jq

SwiftJQ provides you with a native interface for running [jq](https://stedolan.github.io/jq/) on macOS, iOS, tvOS, and watchOS!

## How it works

SwiftJQ wraps the C library for jq with a convenient Swift interface which feels right at home with other swift code. The C library for jq is pulled in as an XCFramework binary target by Swift Package Manager. Currently, this package uses the jq 1.6 release version. To find out more about the pre-compiled static library and verify its authenticity, please check out the [JQ-Darwin repository](https://github.com/Sameesunkaria/JQ-Darwin).

## Installation

You can install the `SwiftJQ` package using Swift Package Manager.

```
https://github.com/Sameesunkaria/SwiftJQ.git
```

`SwiftJQ` is currently only supported on macOS 10.12+, iOS 10.0+, tvOS 10.0+ and watchOS 3.0+. Additionally, `SwiftJQ` imports binary dependencies in the form of XCFrameworks, requiring Xcode 12 or higher. 

>**NOTE:** Due to some bugs related to code signing, this package is only supported on Xcode 12.5 beta 3 or higher. You may use this package on Xcode 12.4, but it may require you to enable the `--deep` code signing flag. This README will be updated with the latest requirements when Xcode 12.5 is released.

## Usage

The `SwiftJQ` package exposes a `JQ` class, which you can use for evaluating any jq program. Running a program is done in two steps:

- Initialization/compilation
- Processing input

### Initialization

Initialize a `JQ` object with the jq program. The program is compiled during this stage. Any compilation errors that may occur are thrown here (see `JQ.InitializationError`). 

An example program which takes in an array of numbers as input and emits all even numbers:

```swift
let program = try JQ(program: ".[] | select(.%2 == 0)")
```

### Processing input

Once the instance of the `JQ` object is initialized, you can use it to process JSON. There are three kinds of methods available for processing JSON; `first`, `one`, and `all`. You may choose a particular kind of method based on your expected output from the jq program. All three methods throw an error if the input is not a valid JSON, the jq program halted with an error, or the jq program encounters an uncaught exception (see `JQ.ProcessingError`). Examples of the three processing methods are shown below:

#### `first`

Returns the first value emitted by the jq program and `nil` if no value is emitted.

The result obtained by processing the `first` output using the program shown in the example for initialization:

```swift
let result = try program.first(for: "[1, 2, 3]")
// result: String? == "2"
```

#### `one`

Returns the first value emitted by the jq program and throws if no value is emitted. `one` is useful when a jq program is expected to produce at least one result.

The result obtained by processing `one` output using the program shown in the example for initialization:

```swift
let result = try program.one(for: "[1, 2, 3]")
// result: String == "2"
```

#### `all`

Returns an array of all the emitted values by the jq program.

The result obtained by processing `all` outputs using the program shown in the example for initialization:

```swift
let result = try program.all(for: "[1, 2, 3, 4, 5, 6]")
// result: [String] == ["2", "4", "6"]
```

### Input and return types

The input JSON which needs to be processed may be provided either as a `String` or a UTF-8 encoded `Data`. The output type of the various processing methods will be the same as the type of the input JSON (as in, a `Data` input will return `Data`) if no output formatter is provided. If you need the output in a different type/format, you can use the methods that take an `OutputFormatter` as an additional argument (e.g. `JQ.all(for:formatter:)`). The available output formatters are listed below:

#### `StringFormatter`

A `StringFormatter` returns the output as a `String`. While initializing a `StringFormatter` you may optionally provide an `OutputConfiguration`. The default `OutputConfiguration` is used if none is provided.

```swift
let program = try JQ(program: "max_by(.price)")

let fruitsJSON = Data("""
  [
    {
      "name": "apple",
      "price": 1.2
    },
    {
      "name": "banana",
      "price": 0.5
    },
    {
      "name": "avocado",
      "price": 2.5
    }
  ]
  """.utf8)

let mostExpensiveFruit = try program.first(
  for: fruitsJSON,
  formatter: StringFormatter())

// mostExpensiveFruit: String? == #"{"name":"avocado","price":2.5}"#
```

#### `DataFormatter`

A `DataFormatter` returns the output as a UTF-8 encoded `Data`. While initializing a `DataFormatter` you may optionally provide an `OutputConfiguration`. The default `OutputConfiguration` is used if none is provided.

```swift
let program = try JQ(program: "max_by(.price)")

let fruitsJSON = """
  [
    {
      "name": "apple",
      "price": 1.2
    },
    {
      "name": "banana",
      "price": 0.5
    },
    {
      "name": "avocado",
      "price": 2.5
    }
  ]
  """

let mostExpensiveFruit = try program.first(
  for: fruitsJSON,
  formatter: DataFormatter())

// mostExpensiveFruit: Data? == Data(#"{"name":"avocado","price":2.5}"#.utf8)
```

#### `DecodableTypeFormatter`

A `DecodableTypeFormatter` returns a decoded Swift type instance conforming to the `Decodable` protocol. If the type fails to decode, the processing method will throw the corresponding `DecodingError`.

```swift
let program = try JQ(program: "max_by(.price)")

let fruitsJSON = """
  [
    {
      "name": "apple",
      "price": 1.2
    },
    {
      "name": "banana",
      "price": 0.5
    },
    {
      "name": "avocado",
      "price": 2.5
    }
  ]
  """

struct Fruit: Codable {
  var name: String
  var price: Double
}

let decoder = JSONDecoder()
let fruitFormatter = DecodableTypeFormatter(
  decoding: Fruit.self, 
  using: decoder)

let mostExpensiveFruit = try program.first(
  for: fruitsJSON,
  formatter: fruitFormatter)

// mostExpensiveFruit: Fruit? == Fruit(name: "avocado", price: 2.5)
```

### Output configuration

`SwiftJQ` lets you apply additional output formatting options to the JSON resulting from processing an input. These options are available on the `OutputConfiguration` struct and correspond to some of the jq command-line flags. The available output configurations are listed below:

#### `sortedKeys`

The output configuration option that sorts keys in lexicographic order.

Example result:
```json
{"c":10,"b":5,"a":11}
```

Result after formatting:
```json
{"a":11,"b":5,"c":10}
```

#### `rawString`

The output configuration option that returns string results directly instead of formatting them as a quoted JSON string. A non-string result will continue to be represented as JSON.

Example result:
```json
"Hello, world!"
```

Result after formatting:
```
Hello, world!
```

#### `pretty`

The output configuration option that uses ample white space and indentation to make output easy to read.

Example result:
```json
{"c":10,"b":5,"a":11}
```

Result after formatting:
```json
{
    "c": 10,
    "b": 5,
    "a": 11
}
```

#### `indent`

The output configuration option that specifies the white space characters to use for indenting the pretty output. This option is only used when the `pretty` output configuration is enabled. 

The `indent` option can represent a fixed number of spaces (`.spaces(Int)`; a maximum of 7 spaces are allowed for each indent level) or a single tab (`.tab`), using the `JQ.OutputConfiguration.IndentSpace` enum.

Example result:
```json
{"c":10,"b":5,"a":11}
```

Result after formatting with `.spaces(2)`:
```json
{
  "c": 10,
  "b": 5,
  "a": 11
}
```

## Performance

`SwiftJQ` uses pre-compiled libraries for jq and oniguruma. Please consult the [JQ-Darwin repository](https://github.com/Sameesunkaria/JQ-Darwin) to know more about the compiler flags.

Generally, the initialization/compilation step is considered a slow step while processing an input is relatively fast. It is not recommended to perform the initialization on the main thread, as it may lead to some frames being dropped, if the application is presenting a UI.

Once a `JQ` object is initialized, you may use it to process inputs from any thread/queue. However, currently, (since a `JQ` object is backed by a single `jq-state` from the jq c library) you can only process one input at a time. If you want to process multiple inputs concurrently, please initialize a new instance of the `JQ` object for each queue. Attempting to processing multiple inputs in parallel may lead to the caller having to wait while another input finishes processing.

## JQ I/O functions

As the jq program is executed from a library instead of being executed from the terminal, some I/O functions behave differently, as they needed a custom implementation to suit our needs. The functions and their behaviors are listed below:

- **`debug`**: Prints the debug output to the console.
- **`halt`**: Halts the execution of the program and returns successfully immediately.
- **`halt_error`**: Fails processing of the input and throws a `JQ.ProcessingError.halt` error.
- **`halt_error/1`**: Fails processing of the input and throws a `JQ.ProcessingError.halt` error, except if the message (input) is `null` and the exit code (first argument) is `0`, where it is treated as a `halt` instead.
- **`input`**: Currently not supported. An exception is thrown if the function is encountered while processing input JSON. You can catch the jq exception by using the jq `try`/`catch` statement.
- **`inputs`**: Currently not supported. Returns jq `empty` if the function is encountered while processing input JSON.
- **`input_filename`**: Currently not supported. Returns `null`.
- **`input_line_number`**: Currently not supported. An exception is thrown if the function is encountered while processing input JSON. You can catch the jq exception by using the jq `try`/`catch` statement.

## JQ Libraries/Modules

`SwiftJQ` supports jq libraries/modules. The terms library and module seem to be used interchangeably; for consistency, we will use the term "library" for the rest of the description. A jq library is a file with the `.jq` extension. It only contains function definitions and no root level jq expressions. You can read more about jq libraries in the [jq manual](https://stedolan.github.io/jq/manual/v1.6/#Modules).

You can pass library search paths along with your jq program during initialization. All search paths must be represented by file system `URL`s to a directory.

```swift
let resourcesURL = Bundle.module.resourceURL!

try JQ(
  program: #"include "hello"; hello"#,
  libraryPaths: [resourcesURL])
```

## License

All code inside this repository is licensed under the MIT license. The `SwiftJQ` package pulls in XCFrameworks for jq and oniguruma, please consult the [JQ-Darwin repository](https://github.com/Sameesunkaria/JQ-Darwin) for relevant licensing information. The XCFrameworks should also contain a copy of the license under which they are being distributed.
