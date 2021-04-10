//  StimuliApp is licensed under the MIT License.
//  Copyright © 2020 Rafael Marín. All rights reserved.

import Foundation

extension Task {

    struct List {
        var numberOfValues: Int
        var bigBlockSize: Int
        var totalSize: Int
        var style: Int
        var groupOrId: String
        var positions: [[Int]]

        var bigBlockNumber: Int {
            return totalSize / bigBlockSize
        }

        var smallBlockSize: Int {
            return bigBlockSize / numberOfValues
        }

        var smallBlockNumberInBig: Int {
            return bigBlockSize / smallBlockSize
        }

        var smallBlockNumber: Int {
            return totalSize / smallBlockSize
        }

        mutating func createPositions(shuffleNumbers: [Int]) {

            positions = []
            var values: [Int] = []

            for i in 0 ..< smallBlockNumber {
                var valuesTemp: [Int] = []
                for _ in 0 ..< smallBlockSize {
                    valuesTemp.append(i % numberOfValues)
                }
                values += valuesTemp
            }

            if shuffleNumbers.isEmpty {
                positions.append(values)
            } else {
                positions.append(AppUtility.reorder(values, with: shuffleNumbers))
            }

        }

        func createShuffleNumbers(seed: UInt64) -> [Int] {
            var values: [Int] = []
            for i in 0 ..< bigBlockNumber {
                let seedItem = UInt64(i + 1) + seed
                let shuffleValues = Array(0 ..< bigBlockSize).shuffled(seed: seedItem)
                values += shuffleValues
            }
            return values
        }

        func createShuffleNumbers2(seed: UInt64) -> [Int] {
            var values: [Int] = []
            for i in 0 ..< smallBlockSize {
                let seedItem = UInt64(i + 1) + seed
                let shuffleValues = Array(i * smallBlockNumber ..< (i + 1) * smallBlockNumber).shuffled(seed: seedItem)
                values += shuffleValues
            }
            return values
        }
    }

    func calculateSection(from section: Section, sceneNumber: Int = 0) -> String {

        sectionTask = SectionTask()

        sectionTask.name = section.name.string
        sectionTask.id = section.id

        guard !section.scenes.isEmpty else {
            return """
            ERROR: there are no scenes in the section: \(section.name.string).
            """
        }

        sectionTask.variableTasks = []
        sectionTask.numberOfTrials = section.totalPossibilities

        guard section.error == "" else { return section.error }

        sectionTask.allVariables = section.variables

        var seedToUse = UInt64.random(in: 0 ... 10000000)

        if let seed = seeds.first(where: { $0.id == section.id }) {
            seedToUse = seed.value
        }

        let seed1 = seedToUse * 101
        let seed2 = seedToUse * 257
        let seed3 = seedToUse * 307
        let seed4 = seedToUse * 401
        let seed5 = seedToUse * 631
        let seed6 = seedToUse * 733

        //style 0 is ordered alternate
        //style 1 is shuffled alternate
        //style 2 is ordered high
        //style 3 is ordered medium
        //style 4 is ordered low
        //style 5 is shuffled

        guard section.totalPossibilities > 0 else {
            return "ERROR"
        }

        guard section.totalPossibilities < Constants.maxNumberOfTrials else {
            return "ERROR: The maximum number of trials allowed is \(Constants.maxNumberOfTrials)"
        }

        let totalNumber = section.totalPossibilities

        for variable in sectionTask.allVariables where variable.group != -1 {
            if let list = variable.listOfValues {
                let numberOfValues = list.values.count
                if totalNumber % numberOfValues != 0 {
                    if let blockVar = sectionTask.allVariables.first(where: { $0.group == -1 }) {
                        return """
                        ERROR: the \(variable.name) has associated the list \(list.name.string) which has \
                        \(numberOfValues) values.
                        The total number of trials in the section is \(totalNumber) that \
                        is given by the variable: \(blockVar.name) which values are controlled by blocks.
                        \(totalNumber) is NOT divisible by \(numberOfValues).
                        """
                    }
                }
            }
        }

        var groups: [Int] = []
        var lists: [List] = []

        for (index, variable) in sectionTask.allVariables.enumerated() {
            let seedItem1 = UInt64(index + 1) * seed1
            let seedItem2 = UInt64(index + 1) * seed2

            guard let selection = FixedSelection(rawValue: variable.selection.string) else { return "ERROR" }

            guard let listOfValues = variable.listOfValues else { return "ERROR" }

            if variable.group != -1 && (variable.group == 0 || !groups.contains(variable.group)) {
                groups.append(variable.group)
                let groupOrId = variable.inGroup ? String(variable.group) : variable.id
                let numberOfValues = listOfValues.values.count
                switch selection {
                case .inOrder:
                    let priority = FixedSelectionPriority(rawValue: variable.selection.properties[0].string) ?? .medium
                    var style = 3
                    if priority == .high {
                        style = 2
                    } else if priority == .low {
                        style = 4
                    }
                    let variables = variable.allVariablesInSameGroup(section: section).map({ $0.id })
                    if variables.contains(section.alternate) {
                        style = 0
                    }
                    let values = List(numberOfValues: numberOfValues,
                                      bigBlockSize: 0,
                                      totalSize: totalNumber,
                                      style: style,
                                      groupOrId: groupOrId,
                                      positions: [])
                    lists.append(values)
                case .shuffled:
                    var style = 5
                    let variables = variable.allVariablesInSameGroup(section: section).map({ $0.id })
                    if variables.contains(section.alternate) {
                        style = 1
                    }
                    let values = List(numberOfValues: numberOfValues,
                                      bigBlockSize: 0,
                                      totalSize: totalNumber,
                                      style: style,
                                      groupOrId: groupOrId,
                                      positions: [])
                    lists.append(values)
                case .random:
                    let style = 10000
                    var diff = FixedSelectionDifferent.equal
                    if !variable.selection.properties.isEmpty {
                        diff = FixedSelectionDifferent(rawValue: variable.selection.properties[0].string) ?? .equal
                    }
                    switch diff {
                    case .equal:
                        var values = List(numberOfValues: numberOfValues,
                                          bigBlockSize: 0,
                                          totalSize: totalNumber,
                                          style: style,
                                          groupOrId: groupOrId,
                                          positions: [])
                        var positions: [Int] = []
                        for i in 0 ..< totalNumber {
                            let seed = seedItem1 + UInt64(i + 1)
                            let value = Int.random(seed: seed, minimum: 0, maximum: numberOfValues - 1)
                            positions.append(value)
                        }
                        values.positions.append(positions)
                        lists.append(values)
                    case .different:
                        let numberOfVars = variable.allVariablesInSameGroup(section: section).count
                        guard numberOfVars <= numberOfValues else {
                            return """
                            ERROR: variable: \(variable.name) is in a group with other variables.
                            All the variables of the group are set to have a different values betweem them.
                            The number of variables in the group is bigger than the number of possible values \
                            that the group can take.
                            """
                        }
                        var values = List(numberOfValues: numberOfValues,
                                          bigBlockSize: 0,
                                          totalSize: totalNumber,
                                          style: style,
                                          groupOrId: groupOrId,
                                          positions: [])
                        var positions: [[Int]] = []
                        for i in 0 ..< totalNumber {
                            let seed = seedItem2 + UInt64(i + 1)
                            positions.append(Array(0 ..< numberOfValues).shuffled(seed: seed))
                        }
                        values.positions = positions
                        lists.append(values)
                    }
                case .fixed:
                    let style = 10000
                    var values = List(numberOfValues: numberOfValues,
                                      bigBlockSize: 0,
                                      totalSize: totalNumber,
                                      style: style,
                                      groupOrId: groupOrId,
                                      positions: [])
                    var positions: [[Int]] = []
                    positions.append(Array(0 ..< numberOfValues))
                    values.positions = positions
                    lists.append(values)
                case .correct:
                    let style = 10000
                    var values = List(numberOfValues: numberOfValues,
                                      bigBlockSize: 0,
                                      totalSize: totalNumber,
                                      style: style,
                                      groupOrId: groupOrId,
                                      positions: [])
                    var positions: [[Int]] = []
                    positions.append(Array(0 ..< numberOfValues))
                    values.positions = positions
                    lists.append(values)
                }
            }
        }

        var newLists = lists.sorted(by: { $0.style < $1.style })
        var bigBlockSize = totalNumber
        var shuffleNumbers: [Int] = []
        var shuffleNumbers2: [Int] = []
        for i in 0 ..< newLists.count {
            let seedItem3 = UInt64(i + 1) * seed3
            let seedItem4 = UInt64(i + 1) * seed4

            newLists[i].bigBlockSize = bigBlockSize
            bigBlockSize /= newLists[i].numberOfValues

            if shuffleNumbers.isEmpty && newLists[i].style == 5 {
                shuffleNumbers = newLists[i].createShuffleNumbers(seed: seedItem3)
            }

            if shuffleNumbers2.isEmpty && newLists[i].style == 1 {
                shuffleNumbers2 = newLists[i].createShuffleNumbers2(seed: seedItem4)
            }

            if newLists[i].style < 10 {
                newLists[i].createPositions(shuffleNumbers: shuffleNumbers)
            }
        }

        var newOrder: [Int] = []
        for index in 0 ..< newLists.count {
            if newLists[index].style == 0 {
                for i in 0 ..< newLists[index].smallBlockSize {
                    for j in 0 ..< newLists[index].smallBlockNumber {
                        newOrder.append(j * newLists[index].smallBlockSize + i)
                    }
                }
                newLists[index].positions[0] = AppUtility.reorder(newLists[index].positions[0], with: newOrder)
            } else if newLists[index].style == 1 {
                for i in 0 ..< newLists[index].smallBlockSize {
                    for j in 0 ..< newLists[index].smallBlockNumber {
                        newOrder.append(j * newLists[index].smallBlockSize + i)
                    }
                }
                newOrder = AppUtility.reorder(newOrder, with: shuffleNumbers2)
                newLists[index].positions[0] = AppUtility.reorder(newLists[index].positions[0], with: newOrder)
            } else if newLists[index].style <= 5 {
                newLists[index].positions[0] = AppUtility.reorder(newLists[index].positions[0], with: newOrder)
            }
        }

        var varis: [VariableTask] = []

        for variable in sectionTask.allVariables where variable.group != -1 {
            guard let selection = FixedSelection(rawValue: variable.selection.string) else { return "ERROR" }
            guard let listOfValues = variable.listOfValues else { return "ERROR" }
            guard let object = variable.object else { return "ERROR" }
            guard let property = variable.property else { return "ERROR" }
            guard let list = newLists.first(where: {
                ($0.groupOrId == String(variable.group) && variable.group != 0)
                    || $0.groupOrId == variable.id || $0.groupOrId == variable.objectId
            }) else { return "ERROR" }

            var positions: [Property] = []
            var numbers: [Int] = []
            var responseDependency: FixedCorrectType?
            var initialValue: Int = 0 //is only calculated for correct selection

            switch selection {
            case .random:
                var diff = FixedSelectionDifferent.equal
                if !variable.selection.properties.isEmpty {
                    diff = FixedSelectionDifferent(rawValue: variable.selection.properties[0].string) ?? .equal
                }
                if diff == .equal {
                    numbers = list.positions[0]
                } else if diff == .different {
                    guard let i = variable.allVariablesInSameGroup(section: section).firstIndex(where: {
                        $0 === variable
                    }) else {
                        return "ERROR"
                    }
                    numbers = list.positions.map({ $0[i] })
                }
            case .fixed:
                guard let varProperty = variable.selection.properties.first(where: {
                    $0.somethingId == variable.id
                }) else { return "ERROR" }
                let number = varProperty.float.toInt - 1
                guard number < list.positions[0].count else { return "ERROR" }
                let number2 = list.positions[0][number]
                numbers = Array(repeating: number2, count: totalNumber)
            case .correct:
                guard let correctType = FixedCorrectType(rawValue: variable.selection.properties[0].string) else {
                    return "ERROR"
                }
                responseDependency = correctType
                var number = 0
                if correctType != .zero {
                    guard let varProperty = variable.selection.properties.first(where: {
                        $0.somethingId == variable.id
                    }) else { return "ERROR" }
                    number = varProperty.float.toInt - 1
                }
                guard number < list.positions[0].count else { return "ERROR" }
                let number2 = list.positions[0][number]
                initialValue = number
                numbers = Array(repeating: number2, count: totalNumber)
            case .inOrder, .shuffled:
                numbers = list.positions[0]
            }

            positions = AppUtility.reorder(listOfValues.goodValues, with: numbers)

            let vari = VariableTask(name: variable.name,
                                    id: variable.id,
                                    object: object,
                                    property: property,
                                    list: listOfValues,
                                    numbers: numbers,
                                    values: positions.map({ Property(from: $0) }),
                                    unit: property.unitName,
                                    jittering: listOfValues.jitteringActive,
                                    jitteringValue: listOfValues.jittering.float,
                                    responseDependency: responseDependency,
                                    initialValue: initialValue)

            varis.append(vari)
        }

        if let variable = sectionTask.allVariables.first(where: { $0.group == -1 }) {

            guard let object = variable.object else { return "ERROR" }
            guard let property = variable.property else { return "ERROR" }
            guard let listOfValues = variable.listOfValues else { return "ERROR" }
            guard let differentBlocks = Int(listOfValues.typesOfBlocks.string) else { return "ERROR" }
            let superList = listOfValues.allValuesBlock

            var seedToUse2 = UInt64.random(in: 0 ... 10000000)

            if let seed = seeds.first(where: { $0.id == listOfValues.id }) {
                seedToUse2 = seed.value
            }

            let seed7 = seedToUse2 * 163 // starting block
            let seed8 = seedToUse2 * 229  // starting list1
            let seed9 = seedToUse2 * 347  // starting list2
            let seed10 = seedToUse2 * 409  // blocks in order
            let seed11 = seedToUse2 * 503  // starting list
            let seed12 = seedToUse2 * 701  // lists in order
            let seed13 = seedToUse2 * 811  // actual random

            let numberOfBlocks = listOfValues.numberOfBlocks.float.toInt
            let lengthOfBlocks = listOfValues.lengthOfBlocks.float.toInt

            var numbers: [Int] = []

            var positions: [Property] = []
            var blocksInOrder: [Int] = []
            var startingLists: [Int] = []
            var probChangeLists: [Float] = []
            guard let lists = listOfValues.blockList else {
                return "ERROR: you need to assign values to all the lists inside the list of blocks "
            }

            if differentBlocks == 1 {

                for item in lists[0] {
                    let error = checkErrors(list: item, variable: variable)
                    if error != "" {
                        return error
                    }
                }

                blocksInOrder = Array(repeating: 0, count: numberOfBlocks)
                startingLists = [calculateFirstFrom(starting: listOfValues.startingList.selectedValue,
                                                        seed: seed8)]
                probChangeLists = [listOfValues.probChangeList.float]

            } else {

                let startingBlock = calculateFirstFrom(starting: listOfValues.startingBlock.selectedValue,
                                                       seed: seed7)
                blocksInOrder = calculateOrder(first: startingBlock,
                                               length: numberOfBlocks,
                                               probChange: listOfValues.probChangeBlock.float,
                                               seed: seed10)

                for lists2 in lists {
                    for item in lists2 {
                        let error = checkErrors(list: item, variable: variable)
                        if error != "" {
                            return error
                        }
                    }
                }

                let startingList1 = calculateFirstFrom(starting: listOfValues.firstBlockStartingList.selectedValue,
                                                       seed: seed8)
                let startingList2 = calculateFirstFrom(starting: listOfValues.secondBlockStartingList.selectedValue,
                                                       seed: seed9)

                startingLists = [startingList1, startingList2]

                let probChangeList1 = listOfValues.firstBlockProbChangeList.float
                let probChangeList2 = listOfValues.secondBlockProbChangeList.float

                probChangeLists = [probChangeList1, probChangeList2]

            }

            for i in 0 ..< numberOfBlocks {

                var startingList = startingLists[blocksInOrder[i]]

                if i != 0 {
                    startingList = calculateFirstFrom(starting: 0, seed: seed11 + UInt64(i))
                }

                let probChangeList = probChangeLists[blocksInOrder[i]]

                let listsInOrder = calculateOrder(first: startingList,
                                                  length: lengthOfBlocks,
                                                  probChange: probChangeList,
                                                  seed: seed12 + UInt64(i))

                for j in 0 ..< listsInOrder.count {
                    let number = i * lengthOfBlocks + j
                    let actualList = lists[blocksInOrder[i]][listsInOrder[j]]
                    let actualRandom = Int.random(seed: seed13 + UInt64(number),
                                                  minimum: 0,
                                                  maximum: actualList.values.count - 1)
                    let actualValue = actualList.values[actualRandom]
                    positions.append(actualValue)

                    if let index = superList.firstIndex(where: { $0.id == actualValue.id }) {
                        numbers.append(index)
                    } else {
                        return "ERROR"
                    }
                }
            }

            let vari = VariableTask(name: variable.name,
                                    id: variable.id,
                                    object: object,
                                    property: property,
                                    list: listOfValues,
                                    numbers: numbers,
                                    values: positions.map({ Property(from: $0) }),
                                    unit: property.unitName,
                                    jittering: listOfValues.jitteringActive,
                                    jitteringValue: listOfValues.jittering.float,
                                    responseDependency: .none,
                                    initialValue: 0)

            varis = [vari] + varis
        }

        for (i, vari) in varis.enumerated() {

            if vari.jittering {
                for (j, item) in vari.values.enumerated() {
                    let seed = (seed5 * UInt64(i + 1)) + (seed6 * UInt64(j + 1))
                    let value = vari.jitteringValue

                    let float = Float.random(seed: seed, minimum: -value, maximum: value)
                    let float1 = Float.random(seed: seed + 1, minimum: -value, maximum: value)
                    let float2 = Float.random(seed: seed + 2, minimum: -value, maximum: value)

                    item.float += float
                    item.float1 += float1
                    item.float2 += float2

                    item.unit = vari.property.unit
                    item.timeUnit = vari.property.timeUnit
                    item.timeExponent = vari.property.timeExponent
                    item.unitType = vari.property.unitType
                    item.changeValue(new: [item.float, item.float1, item.float2])
                }
            } else {
                for item in vari.values {
                    item.unit = vari.property.unit
                    item.timeUnit = vari.property.timeUnit
                    item.timeExponent = vari.property.timeExponent
                    item.unitType = vari.property.unitType
                    item.changeValue(new: [item.float, item.float1, item.float2])
                }
            }
        }

        sectionTask.variableTasks = varis

        if let variable = section.trialValue.variable, let property = variable.property, let object = variable.object,
            let variableTask = varis.first(where: { $0.property === property && $0.object === object }) {

            guard let valueType = FixedValueType(rawValue: section.trialValue.properties[0].string) else {
                return "ERROR"
            }

            if valueType == .same {
                let value = VariableTask(name: "trialValue",
                                         id: NSUUID().uuidString,
                                         object: object,
                                         property: property,
                                         list: variableTask.list,
                                         numbers: variableTask.numbers,
                                         values: variableTask.values,
                                         unit: "",
                                         jittering: false,
                                         jitteringValue: 0,
                                         responseDependency: variableTask.responseDependency,
                                         initialValue: variableTask.initialValue)
                sectionTask.variableTasks += [value]
                variableTask.trialValueAssociated = value
            } else {

                if variable.listOfValues?.dimensions == 8 {

                    var valuesToUse: [Property] = []

                    for number in variableTask.numbers {
                        valuesToUse.append(section.trialValue.properties[0].properties[number])
                    }

                    let value = VariableTask(name: "trialValue",
                                             id: NSUUID().uuidString,
                                             object: object,
                                             property: property,
                                             list: variableTask.list,
                                             numbers: variableTask.numbers,
                                             values: valuesToUse,
                                             unit: "",
                                             jittering: false,
                                             jitteringValue: 0,
                                             responseDependency: variableTask.responseDependency,
                                             initialValue: variableTask.initialValue)
                    sectionTask.variableTasks += [value]
                    variableTask.trialValueAssociated = value

                } else {
                    let newList = ListOfValues(name: "", order: -1, type: .values)

                    newList.values = section.trialValue.properties[0].properties

                    guard let reordenation = variable.listOfValues?.reordenation else { return "ERROR" }

                    var positions = AppUtility.reorder(newList.values, with: reordenation)
                    positions = AppUtility.reorder(positions, with: variableTask.numbers)

                    let value = VariableTask(name: "trialValue",
                                             id: NSUUID().uuidString,
                                             object: object,
                                             property: property,
                                             list: newList,
                                             numbers: variableTask.numbers,
                                             values: positions,
                                             unit: "",
                                             jittering: false,
                                             jitteringValue: 0,
                                             responseDependency: variableTask.responseDependency,
                                             initialValue: variableTask.initialValue)
                    sectionTask.variableTasks += [value]
                    variableTask.trialValueAssociated = value
                }
            }

            var dimensionsTrial = sectionTask.variableTasks.first(where: {
                $0.name == "trialValue" })?.list.dimensions ?? 0

            if dimensionsTrial > 3 {
                dimensionsTrial = 1 //we take the numeric value for images, texts...
            }
            var dimensionsResponse = 0

            if section.responseValue.properties.isEmpty {
                dimensionsResponse = 0
            } else if let fixedCorrect = FixedCorrect(rawValue: section.responseValue.string) {
                if dimensionsTrial != 0 {
                    switch fixedCorrect {
                    case .positionX, .positionY, .positionRadius, .positionAngle, .value:
                        dimensionsResponse = 1
                    case .positionVector:
                        dimensionsResponse = 2
                    }
                }
            }

            guard dimensionsTrial == dimensionsResponse || dimensionsResponse == 0 else {

                func dimToString(dimensions: Int) -> String {
                    if dimensions == 1 {
                        return "is a numeric value"
                    } else if dimensions == 2 {
                        return "is a 2d vector"
                    } else if dimensions == 3 {
                        return "is a color (3d vector)"
                    } else {
                        return "does not exist"
                    }
                }

                let trialString = dimToString(dimensions: dimensionsTrial)
                let responseString = dimToString(dimensions: dimensionsResponse)

                return """
                ERROR: trialValue \(trialString) and responseValue \(responseString)
                """
            }

        }

        for scene in section.scenes {
            let errorScene = calculateScene(from: scene)
            if errorScene != "" {
                return errorScene
            }
        }

        calculateSectionValue(from: section)

        calculateSectionNext(from: section)

        sectionTask.sceneNumber = sceneNumber

        sectionTasks.append(sectionTask)
        return ""
    }

    private func checkErrors(list: ListOfValues, variable: Variable) -> String {
        if list.jitteringActive {
            return """
            ERROR: the list: \(list.name.string) has jittering.
            It is not possible to use jittering in lists that are controlled by blocks.
            Please go to the list and turn the jittering off.
            """
        }
        if list.dimensions != variable.dimensions &&
            !(variable.dimensions > 3 && list.dimensions == 1) {
            var varDim = "requires single values"
            if variable.dimensions == 2 {
                varDim = "requires 2d vector values"
            } else if variable.dimensions == 2 {
                varDim = "requires 3d vector values"
            }
            var itemDim = "contains single values"
            if list.dimensions == 2 {
                itemDim = "contains 2d vector values"
            } else if list.dimensions == 3 {
                itemDim = "contains 3d vector values"
            }

            return """
            ERROR: the list: \(list.name.string) \(itemDim).
            The variable that uses this list: \(variable.name) \(varDim)"
            """
        }
        return ""
    }

    private func calculateOrder(first: Int, length: Int, probChange: Float, seed: UInt64) -> [Int] {

        var myList: [Int] = Array(repeating: first, count: length)

        for i in 1 ..< length {
            let random = Float.random(seed: seed + UInt64(i), minimum: 0, maximum: 1)
            if random < probChange {
                if myList[i - 1] == 0 {
                    myList[i] = 1
                } else {
                    myList[i] = 0
                }
            } else {
                myList[i] = myList[i - 1]
            }
        }
        return myList
    }

    private func calculateFirstFrom(starting: Int, seed: UInt64) -> Int {
        var first = 0
        if starting == 0 {
            first = Int.random(seed: seed, minimum: 0, maximum: 1)
        } else if starting == 2 {
            first = 1
        }
        return first
    }

    private func calculateSectionNext(from section: Section) {
        for property in section.next.properties {

            if let conditionType = FixedCondition(rawValue: property.info) {
                let n = Int(round(property.float))
                var sectionNumber = -1

                if property.somethingId != "" {
                    sectionNumber = Flow.shared.test.sections.firstIndex(where: { $0.id == property.somethingId}) ?? -1
                }
                let condition = Condition(type: conditionType, n: n, sectionNumber: sectionNumber)
                sectionTask.conditions.append(condition)
            }
        }

        var sectionNumber = -1
        if section.next.somethingId != "" {
            sectionNumber = Flow.shared.test.sections.firstIndex(where: { $0.id == section.next.somethingId}) ?? -1
        }

        let condition = Condition(type: nil, n: 0, sectionNumber: sectionNumber)
        sectionTask.conditions.append(condition)
    }

    private func calculateSectionValue(from section: Section) {

        sectionTask.sectionValueType = FixedResponseValue(rawValue: section.responseValue.string)
        sectionTask.defaultValueNoResponse = nil
        if section.trialValue.properties.count > 0 {
            sectionTask.sectionSame = FixedValueType(rawValue: section.trialValue.properties[0].string) ?? .same
        }
        if section.responseValue.properties.count > 0 {
            sectionTask.sectionValueDifference = section.responseValue.properties[0].float
            if section.responseValue.properties.count > 1 {

                if let val = FixedCorrect2(rawValue: section.responseValue.properties[1].string) {
                    if val == .defaultValue {
                        sectionTask.defaultValueNoResponse = section.responseValue.properties[1].properties[0].float
                    }
                }
            }
        }

        guard let variableValue = sectionTask.variableTasks.first(where: { $0.name == "trialValue" }) else { return }

        if sectionTask.sectionSame == .same {
            if variableValue.list.dimensions == 1 || variableValue.list.dimensions > 3 {
                sectionTask.sectionValues = variableValue.values.map({ $0.float / $0.unit.factor })
            } else if variableValue.list.dimensions == 2 {
                if let valueType = sectionTask.sectionValueType {
                    let x = variableValue.values.map({ $0.float / $0.unit.factor })
                    let y = variableValue.values.map({ $0.float1 / $0.unit.factor })
                    switch valueType {
                    case .position, .xPosition, .yPosition:
                        sectionTask.sectionValues = x
                        sectionTask.sectionValues1 = y
                    case .radiusPosition, .anglePosition:
                        var radius: [Float] = []
                        var angles: [Float] = []
                        for i in 0 ..< x.count {
                            let polar = AppUtility.cartesianToPolar(xPos: x[i], yPos: y[i])
                            radius.append(polar.0)
                            angles.append(polar.1)
                        }
                        sectionTask.sectionValues = radius
                        sectionTask.sectionValues1 = angles
                    case .value:
                        break
                    }
                }
            }
        } else {
            sectionTask.sectionValues = variableValue.values.map({ $0.float / $0.unit.factor })
        }
    }

    func calculateSectionValue(trial: Int, variableValue: VariableTask) {

        let value = variableValue.values[trial]

        if sectionTask.sectionSame == .same {
            if variableValue.list.dimensions == 1 || variableValue.list.dimensions > 3 {
                sectionTask.sectionValues[trial] = value.float / value.unit.factor
            } else if variableValue.list.dimensions == 2 {
                if let valueType = sectionTask.sectionValueType {
                    let x = value.float / value.unit.factor
                    let y = value.float1 / value.unit.factor
                    switch valueType {
                    case .position, .xPosition, .yPosition:
                        sectionTask.sectionValues[trial] = x
                        sectionTask.sectionValues1[trial] = y
                    case .radiusPosition, .anglePosition:
                        let polar = AppUtility.cartesianToPolar(xPos: x, yPos: y)
                        sectionTask.sectionValues[trial] = polar.0
                        sectionTask.sectionValues1[trial] = polar.1
                    case .value:
                        break
                    }
                }
            }
        } else {
            sectionTask.sectionValues[trial] = value.float / value.unit.factor
        }
    }
}
