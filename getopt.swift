// SPDX-License-Identifier: BSL-1.0

// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          https://www.boost.org/LICENSE_1_0.txt)

enum OptArgRequirement
{
    case no
    case yes
    case optional
}

struct OptDescriptor<Id>
{
    let id: Id
    let shortName: Character?
    let longName: String?
    let hasArg: OptArgRequirement
}

struct Opt<Id>
{
    let name: Substring
    let value: Substring?
    let descriptor: OptDescriptor<Id>?
}

private struct InternalOpt
{
    let name: Substring
    let value: Substring?
    let descriptorIndex: Int?
}

private let optEndMarker = "--"

private struct LongOpt
{
    let opt: InternalOpt

    private static let prefix = "--"

    private static func dropPrefix(
        _ argument: String
    ) -> Substring?
    {
        guard argument.count > LongOpt.prefix.count &&
              argument.hasPrefix(LongOpt.prefix) else
        {
            return nil
        }

        return argument.dropFirst(LongOpt.prefix.count)
    }

    private static func findDescriptor<Id>(
        for longName: Substring,
        from descriptors: [OptDescriptor<Id>]
    ) -> Int?
    {
        return descriptors.firstIndex(where:
        {
            guard let _longName = $0.longName else
            {
                return false
            }

            return _longName == longName
        })
    }

    private static func popFirst(
        _ argumentQueue: inout ArraySlice<String>
    ) -> Substring?
    {
        guard let element = argumentQueue.popFirst() else
        {
            return nil
        }

        return Substring(element)
    }

    private static func getSeparateValueIfApplicable<Id>(
        from argumentQueue: inout ArraySlice<String>,
        with descriptor: OptDescriptor<Id>
    ) -> Substring?
    {
        switch descriptor.hasArg
        {
        case .no, .optional:
            return nil

        case .yes:
            return LongOpt.popFirst(&argumentQueue)
        }
    }

    init?<Id>(
        _ argumentQueue: inout ArraySlice<String>,
        _ descriptors: [OptDescriptor<Id>]
    )
    {
        guard let argument = argumentQueue.first else
        {
            assertionFailure()
            return nil
        }

        guard let optString = LongOpt.dropPrefix(argument) else
        {
            return nil
        }
        argumentQueue.removeFirst() // accept

        var name: Substring
        var value: Substring?
        var descriptorIndex: Int?

        if let delimiterIndex = optString.firstIndex(of: "=")
        {
            // the option string contains a value

            name = optString.prefix(upTo: delimiterIndex)
            value = optString.suffix(from: optString.index(after: delimiterIndex))
            descriptorIndex = LongOpt.findDescriptor(for: name, from: descriptors)
        }
        else
        {
            // the next argument may be a value of the option

            name = optString
            descriptorIndex = LongOpt.findDescriptor(for: name, from: descriptors)

            if let descriptorIndex = descriptorIndex
            {
                value = LongOpt.getSeparateValueIfApplicable(
                    from: &argumentQueue,
                    with: descriptors[descriptorIndex])
            }
            else
            {
                value = nil
            }
        }

        self.opt = InternalOpt(
            name: name,
            value: value,
            descriptorIndex: descriptorIndex)
    }
}

private struct ShortOpts
{
    let opts: [InternalOpt]

    private static let prefix: Character = "-"

    private static func dropPrefix(
        _ argument: String
    ) -> Substring?
    {
        guard argument.count >= 2 &&
              argument.first! == ShortOpts.prefix &&
              argument.dropFirst().first! != ShortOpts.prefix else
        {
            return nil
        }

        return argument.dropFirst()
    }

    private static func findDescriptor<Id>(
        for shortName: Character,
        from descriptors: [OptDescriptor<Id>]
    ) -> Int?
    {
        return descriptors.firstIndex(where:
        {
            guard let _shortName = $0.shortName else
            {
                return false
            }

            return _shortName == shortName
        })
    }

    private static func popFirst(
        _ characterQueue: inout Substring
    ) -> Substring?
    {
        guard !characterQueue.isEmpty else
        {
            return nil
        }

        let startIndex = characterQueue.startIndex
        let endIndex = characterQueue.index(startIndex, offsetBy: 1)
        let substring = characterQueue[startIndex..<endIndex]

        characterQueue.removeFirst()
        return substring
    }

    private static func getTrailingValueIfApplicable<Id>(
        from characterQueue: inout Substring,
        with descriptor: OptDescriptor<Id>
    ) -> Substring?
    {
        switch descriptor.hasArg
        {
        case .no:
            return nil

        case .yes, .optional:
            guard !characterQueue.isEmpty else
            {
                return nil
            }

            let value = characterQueue;
            characterQueue.removeAll()
            return value
        }
    }

    private static func popFirst(
        _ argumentQueue: inout ArraySlice<String>
    ) -> Substring?
    {
        guard let element = argumentQueue.popFirst() else
        {
            return nil
        }

        return Substring(element)
    }

    private static func getSeparateValueIfApplicable<Id>(
        from argumentQueue: inout ArraySlice<String>,
        with descriptor: OptDescriptor<Id>
    ) -> Substring?
    {
        switch descriptor.hasArg
        {
        case .no, .optional:
            return nil

        case .yes:
            return ShortOpts.popFirst(&argumentQueue)
        }
    }

    init?<Id>(
        _ argumentQueue: inout ArraySlice<String>,
        _ descriptors: [OptDescriptor<Id>]
    )
    {
        guard let argument = argumentQueue.first else
        {
            assertionFailure()
            return nil
        }

        guard let optString = ShortOpts.dropPrefix(argument) else
        {
            return nil
        }
        argumentQueue.removeFirst() // accept

        var opts: [InternalOpt] = []
        var characterQueue = optString
        while !characterQueue.isEmpty
        {
            let name = ShortOpts.popFirst(&characterQueue)!
            let descriptorIndex = ShortOpts.findDescriptor(for: name.first!, from: descriptors)

            var value: Substring?
            if let descriptorIndex = descriptorIndex
            {
                let descriptor = descriptors[descriptorIndex]

                value = ShortOpts.getTrailingValueIfApplicable(
                    from: &characterQueue,
                    with: descriptor)
                if value == nil
                {
                    value = ShortOpts.getSeparateValueIfApplicable(
                        from: &argumentQueue,
                        with: descriptor)
                }
            }
            else
            {
                value = nil
            }

            opts.append(InternalOpt(
                name: name,
                value: value,
                descriptorIndex: descriptorIndex))
        }
        self.opts = opts
    }
}

func getopt<Id>(
    _ arguments: [String],
    _ descriptors: [OptDescriptor<Id>],
    _ callback: (Opt<Id>) -> Void
) -> [String]
{
    func getDescriptor(
        for opt: InternalOpt,
        from descriptors: [OptDescriptor<Id>]
    ) -> OptDescriptor<Id>?
    {
        guard let descriptorIndex = opt.descriptorIndex else
        {
            return nil
        }

        guard descriptorIndex < descriptors.count else
        {
            assert(false)
            return nil
        }

        return descriptors[descriptorIndex]
    }

    func invokeCallback(
        _ opt: InternalOpt,
        _ descriptors: [OptDescriptor<Id>],
        _ callback: (Opt<Id>) -> Void
    ) -> Void
    {
        let _opt = Opt(
            name: opt.name,
            value: opt.value,
            descriptor: getDescriptor(for: opt, from: descriptors))

        callback(_opt)
    }

    guard arguments.count >= 2 else
    {
        return []
    }

    var argumentQueue = arguments.dropFirst()
    var nonOptArguments: [String] = []
    while !argumentQueue.isEmpty
    {
        if let longOpt = LongOpt(&argumentQueue, descriptors)
        {
            invokeCallback(longOpt.opt, descriptors, callback)
        }
        else if let shortOpts = ShortOpts(&argumentQueue, descriptors)
        {
            for opt in shortOpts.opts
            {
                invokeCallback(opt, descriptors, callback)
            }
        }
        else
        {
            let argument = argumentQueue.popFirst()!

            if argument == optEndMarker
            {
                nonOptArguments += argumentQueue
                break
            }

            nonOptArguments.append(argument)
        }
    }

    return nonOptArguments
}
