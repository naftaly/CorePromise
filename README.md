# CorePromise

[![Build Status](https://travis-ci.org/naftaly/CorePromise.svg?branch=master)](https://travis-ci.org/naftaly/CorePromise)

CorePromise is a Promise framework.

## Installation

CorePromise is available on [CocoaPods](http://cocoapods.org). Just add the following to your project Podfile:

```ruby
pod 'CorePromise'
```

## Usage

Use it as follows:

```objective-c
#import <CorePromise/CorePromise.h>

[CPPromise promise]
.then( ^id(id nop) {
	return nil;
});

 ```

## License

CorePromise is released under a MIT License. See LICENSE file for details.


