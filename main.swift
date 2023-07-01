// SPDX-License-Identifier: BSL-1.0

// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          https://www.boost.org/LICENSE_1_0.txt)

enum MyOptId
{
    case A
    case B
    case C
    case D
    case E
}

let myOptDescs: [OptDescriptor<MyOptId>] =
[
    OptDescriptor(id: .A, shortName: "a", longName: "aaa", hasArg: .no),
    OptDescriptor(id: .B, shortName: "b", longName: "bbb", hasArg: .yes),
    OptDescriptor(id: .C, shortName: "c", longName: "ccc", hasArg: .optional),
    OptDescriptor(id: .D, shortName: "d", longName:   nil, hasArg: .no),
    OptDescriptor(id: .E, shortName: nil, longName: "eee", hasArg: .no),
]

let nonOptArgs = getopt(CommandLine.arguments, myOptDescs)
{
    opt in

    guard let descriptor = opt.descriptor else
    {
        print("unrecognized option `\(opt.name)'")
        return
    }

    if opt.value != nil && descriptor.hasArg == .no
    {
        print("option `\(opt.name)' doesn't allow an argument")
        return
    }

    if opt.value == nil && descriptor.hasArg == .yes
    {
        print("option `\(opt.name)' requires an argument")
        return
    }

    if let value = opt.value
    {
        print("option \(opt.name) with arg \(value)")
    }
    else
    {
        print("option \(opt.name)")
    }
}

if !nonOptArgs.isEmpty
{
    print("non-option ARGV-elements:", terminator: "")
    for arg in nonOptArgs
    {
        print(" \(arg)", terminator: "")
    }
    print("")
}
