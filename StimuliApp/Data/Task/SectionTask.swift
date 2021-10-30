//  StimuliApp is licensed under the MIT License.
//  Copyright © 2020 Rafael Marín. All rights reserved.

import Foundation

struct Condition {

    var type: FixedCondition?
    var n: Int
    var sectionNumber: Int
}

struct SectionResult {
    var result: String
    var csv0: String
    var csv0Name: String
    var csv1: String
    var csv1Name: String
}

class SectionTask {

    var id: String = ""
    var name: String = ""
    var sceneTasks: [SceneTask] = []
    var variableTasks: [VariableTask] = []
    var numberOfTrials: Int = 1
    var allVariables: [Variable] = []
    var conditions: [Condition] = []

    var sectionValueType: FixedCorrect?
    var sectionValueType2: FixedCorrect3?
    var sectionValues: [Float] = []
    var sectionValues1: [Float] = []
    var sectionValues2: [Float] = []
    var sectionValueDifference: Float = 0.001
    var defaultValueNoResponse: Float? = nil
    var sectionSame: FixedValueType = .same

    var blocks: [String] = []

    var sceneNumber: Int = 0
    var currentTrial: Int = 0
    var numberOfCorrects: Int = 0
    var numberOfIncorrects: Int = 0
    var numberOfRespondedInTime: Int = 0
    var numberOfNotRespondedInTime: Int = 0
    var last: Int = 1 //by default is correct

    var dependentValue = 0
    var previousDependentSum = 0
    var starting = true

    var correctValue: [Int] = [] //trial
    var respondedValue: [Int] = [] //trial

    var respondedInTime: Bool = true //if any response in the section is not in time or is not given this is false
    var respondedOutTime: Bool = false

    var infoName: String {
        return "SECTION: " + name
    }

    var infoTrialsTotal: String {
        return "NUMBER OF TRIALS: " + String(numberOfTrials)
    }

    var infoAllVariablesWithValues: String {
        let title = "VALUES OF EACH VARIABLE IN ORDER: "
        var value = variableTasks.map({ $0.info }).joined(separator: "\n\n")

        if !blocks.isEmpty {
            value += "\n\n" + "block:" + "\n" + blocks.joined(separator: ",")
        }
        return title + "\n\n" + value
    }

    var infoAllVariables: [String] {
        return variableTasks.map({ $0.shortInfo })
    }

    var infoAllTrialsTitle: String {
        return "VALUES OF EACH TRIAL: "
    }

    var infoAllTrialsTitleVariables: [String] {
        var value = variableTasks.map({ $0.name })

        if !blocks.isEmpty {
            value += ["block"]
        }

        return value
    }

    var infoAllTrialsValues: [[String]] {
        var values: [[String]] = Array(repeating: [], count: numberOfTrials)

        for element in variableTasks {
            if element.responseDependency != nil {
                for i in 0 ..< element.values.count {
                    values[i].append("x")
                }
            } else {
                for (index, position) in element.values.enumerated() {
                    values[index].append(position.stringWithoutUnit)
                }
            }
        }

        for (index, value) in blocks.enumerated() {
            values[index].append(value)
        }
        return values
    }

    var infoAllTrialsValuesSaved: [[String]] {
        var values: [[String]] = Array(repeating: [], count: numberOfTrials)

        for element in variableTasks {
            for (index, position) in element.values.enumerated() {
                values[index].append(position.stringWithoutUnit)
            }
        }

        for (index, value) in blocks.enumerated() {
            values[index].append(value)
        }
        
        return values
    }

    var info: String {
        if Task.shared.error == "" {

            var string = Constants.separator + infoName + Constants.separator + infoTrialsTotal + Constants.separator

            if infoAllTrialsValues[0].count > 0 {
                let titles = "trial," + infoAllTrialsTitleVariables.joined(separator: ",")
                var valuesArray: [String] = []
                for (index, element) in infoAllTrialsValues.enumerated() {
                    valuesArray.append(String(index + 1) + "," + element.joined(separator: ","))
                }
                let values = valuesArray.joined(separator: "\n\n")

                let infoAllTrials = infoAllTrialsTitle + "\n\n" + titles + "\n\n" + values

                string += infoAllVariablesWithValues + Constants.separator + infoAllTrials + Constants.separator
            }
            return string
        } else {
            return Task.shared.error
        }
    }

    func calculateResultInfo() -> SectionResult {

        let respondedTrials = correctValue.count

        var titles: [String] = ["trial"]
        var titlesUnit: [String] = ["trial"]
        var values: [[String]] = []
        var titlesPath: [String] = []
        var valuesPath: [[String]] = []

        var includeRespondedInTime = false
        var includeCorrect = false

        //titles & titlesUnit
        for sceneTask in sceneTasks {
            titles.append("\(sceneTask.name)_duration")
            titlesUnit.append("\(sceneTask.name)_duration (s)")
            titles.append("\(sceneTask.name)_delayDisplay")
            titlesUnit.append("\(sceneTask.name)_delayDisplay (s)")
        }

        titles += infoAllTrialsTitleVariables
        titlesUnit += infoAllVariables

        for sceneTask in sceneTasks {
            switch sceneTask.responseType {
            case .none:
                break
            case .leftRight, .topBottom, .touchObject:
                includeRespondedInTime = true
                titles.append("\(sceneTask.name)_responseTime")
                titlesUnit.append("\(sceneTask.name)_responseTime (s)")
                titles.append("\(sceneTask.name)_response")
                titlesUnit.append("\(sceneTask.name)_response")

                titles.append("\(sceneTask.name)_touchPositionX")
                titles.append("\(sceneTask.name)_touchPositionY")
                titlesUnit.append("\(sceneTask.name)_touchPositionX (pixels)")
                titlesUnit.append("\(sceneTask.name)_touchPositionY (pixels)")
            case .keyboard, .keys:
                includeRespondedInTime = true
                titles.append("\(sceneTask.name)_responseTime")
                titlesUnit.append("\(sceneTask.name)_responseTime (s)")
                titles.append("\(sceneTask.name)_response")
                titlesUnit.append("\(sceneTask.name)_response")
            case .touchMultipleObjects:
                includeRespondedInTime = true
                titles.append("\(sceneTask.name)_responseTime")
                titlesUnit.append("\(sceneTask.name)_responseTime (s)")
                titles.append("\(sceneTask.name)_response")
                titlesUnit.append("\(sceneTask.name)_response")
            case .touch:
                includeRespondedInTime = true
                titles.append("\(sceneTask.name)_responseTime")
                titlesUnit.append("\(sceneTask.name)_responseTime (s)")

                let coordinate = sceneTask.responseCoordinates
                let unit1 = sceneTask.responseFirstUnit
                let unit2 = sceneTask.responseSecondUnit
                switch coordinate {
                case .cartesian:
                    titles.append("\(sceneTask.name)_touchPositionX")
                    titles.append("\(sceneTask.name)_touchPositionY")
                    titlesUnit.append("\(sceneTask.name)_touchPositionX (\(unit1.name))")
                    titlesUnit.append("\(sceneTask.name)_touchPositionY (\(unit2.name))")
                case .polar:
                    titles.append("\(sceneTask.name)_touchPositionRadius")
                    titles.append("\(sceneTask.name)_touchPositionAngle")
                    titlesUnit.append("\(sceneTask.name)_touchPositionRadius (\(unit1.name))")
                    titlesUnit.append("\(sceneTask.name)_touchPositionAngle (\(unit2.name))")
                }
            case .twoFingersTouch:
                includeRespondedInTime = true
                titles.append("\(sceneTask.name)_responseTime")
                titlesUnit.append("\(sceneTask.name)_responseTime (s)")
                titles.append("\(sceneTask.name)_response")
                titlesUnit.append("\(sceneTask.name)_response")

                let coordinate = sceneTask.responseCoordinates
                let unit1 = sceneTask.responseFirstUnit
                let unit2 = sceneTask.responseSecondUnit
                switch coordinate {
                case .cartesian:
                    titles.append("\(sceneTask.name)_touch1PositionX")
                    titles.append("\(sceneTask.name)_touch1PositionY")
                    titlesUnit.append("\(sceneTask.name)_touch1PositionX (\(unit1.name))")
                    titlesUnit.append("\(sceneTask.name)_touch1PositionY (\(unit2.name))")
                    titles.append("\(sceneTask.name)_touch2PositionX")
                    titles.append("\(sceneTask.name)_touch2PositionY")
                    titlesUnit.append("\(sceneTask.name)_touch2PositionX (\(unit1.name))")
                    titlesUnit.append("\(sceneTask.name)_touch2PositionY (\(unit2.name))")
                case .polar:
                    titles.append("\(sceneTask.name)_touch1PositionRadius")
                    titles.append("\(sceneTask.name)_touch1PositionAngle")
                    titlesUnit.append("\(sceneTask.name)_touch1PositionRadius (\(unit1.name))")
                    titlesUnit.append("\(sceneTask.name)_touch1PositionAngle (\(unit2.name))")
                    titles.append("\(sceneTask.name)_touch2PositionRadius")
                    titles.append("\(sceneTask.name)_touch2PositionAngle")
                    titlesUnit.append("\(sceneTask.name)_touch2PositionRadius (\(unit1.name))")
                    titlesUnit.append("\(sceneTask.name)_touch2PositionAngle (\(unit2.name))")
                }
            case .lift:
                includeRespondedInTime = true
                titles.append("\(sceneTask.name)_responseTime")
                titlesUnit.append("\(sceneTask.name)_responseTime (s)")
                titles.append("\(sceneTask.name)_response")
                titlesUnit.append("\(sceneTask.name)_response")
            case .path, .moveObject:
                includeRespondedInTime = true
                titles.append("\(sceneTask.name)_responseTime")
                titlesUnit.append("\(sceneTask.name)_responseTime (s)")

                if sceneTask.responseType == .moveObject {
                    titles.append("\(sceneTask.name)_response")
                    titlesUnit.append("\(sceneTask.name)_response")
                }

                let coordinate = sceneTask.responseCoordinates
                let unit1 = sceneTask.responseFirstUnit
                let unit2 = sceneTask.responseSecondUnit
                switch coordinate {
                case .cartesian:
                    titles.append("\(sceneTask.name)_finalPositionX")
                    titles.append("\(sceneTask.name)_finalPositionY")
                    titlesUnit.append("\(sceneTask.name)_finalPositionX (\(unit1.name))")
                    titlesUnit.append("\(sceneTask.name)_finalPositionX (\(unit2.name))")
                case .polar:
                    titles.append("\(sceneTask.name)_finalPositionRadius")
                    titles.append("\(sceneTask.name)_finalPositionAngle")
                    titlesUnit.append("\(sceneTask.name)_finalPositionRadius (\(unit1.name))")
                    titlesUnit.append("\(sceneTask.name)_finalPositionAngle (\(unit2.name))")
                }
            }
            if sceneTask.isRealResponse {
                includeCorrect = true
            }
        }

        if includeRespondedInTime {
            titles.append("respondedInTime")
            titlesUnit.append("respondedInTime")
        }

        if includeCorrect {
            titles.append("correct")
            titlesUnit.append("correct")
        }

        //values
        for i in 0 ..< respondedTrials {
            let trial = String((i % numberOfTrials) + 1)
            values.append([trial])
        }

        for sceneTask in sceneTasks {
            for i in 0 ..< respondedTrials {
                let newValue = String(format: "%.4f", sceneTask.realEndTime[i] - sceneTask.realStartTime[i])
                values[i].append(newValue)
                let newValue2 = String(format: "%.4f", sceneTask.delayTime[i])
                values[i].append(newValue2)
            }
        }

        let infoAllTrials = infoAllTrialsValuesSaved

        for i in 0 ..< respondedTrials {
            let trial = i % numberOfTrials
            if !infoAllTrials[trial].isEmpty {
                values[i] += infoAllTrials[trial]
            }
        }

        for sceneTask in sceneTasks {
            switch sceneTask.responseType {
            case .none:
                break
            case .leftRight, .topBottom, .touchObject:
                for i in 0 ..< respondedTrials {
                    var newValue = "NaN"

                    if let clock2 = sceneTask.userResponses[i].liftClock {
                        newValue = String(format: "%.4f", clock2)
                    } else if let clock = sceneTask.userResponses[i].clocks.last {
                        newValue = String(format: "%.4f", clock)
                    }
                    values[i].append(newValue)

                    if let response = sceneTask.userResponses[i].string {
                        values[i].append(response)
                    } else if sceneTask.isRealResponse {
                        if let response = Task.shared.sectionTask.defaultValueNoResponse {
                            values[i].append(String(response))
                        } else {
                            values[i].append("NaN")
                        }
                    } else {
                        values[i].append("NaN")
                    }

                    if let x = sceneTask.userResponses[i].xTouches.last,
                        let y = sceneTask.userResponses[i].yTouches.last {
                        values[i].append("\(x)")
                        values[i].append("\(y)")
                    } else {
                        values[i].append("NaN")
                        values[i].append("NaN")
                    }
                }
            case .keyboard, .keys, .lift, .touchMultipleObjects:
                for i in 0 ..< respondedTrials {
                    var newValue = "NaN"

                    if let clock2 = sceneTask.userResponses[i].liftClock {
                        newValue = String(format: "%.4f", clock2)
                    } else if let clock = sceneTask.userResponses[i].clocks.last {
                        newValue = String(format: "%.4f", clock)
                    }
                    values[i].append(newValue)

                    if let response = sceneTask.userResponses[i].string {
                        values[i].append(response)
                    } else if sceneTask.isRealResponse {
                        if let response = Task.shared.sectionTask.defaultValueNoResponse {
                            values[i].append(String(response))
                        } else {
                            values[i].append("NaN")
                        }
                    } else {
                        values[i].append("NaN")
                    }
                }

            case .touch, .path, .moveObject:
                for i in 0 ..< respondedTrials {
                    var newValue = "NaN"

                    if let clock2 = sceneTask.userResponses[i].liftClock {
                        newValue = String(format: "%.4f", clock2)
                    } else if let clock = sceneTask.userResponses[i].clocks.last {
                        newValue = String(format: "%.4f", clock)
                    }
                    values[i].append(newValue)

                    if sceneTask.responseType == .moveObject {
                        if let response = sceneTask.userResponses[i].string {
                            values[i].append(response)
                        } else if sceneTask.isRealResponse {
                            if let response = Task.shared.sectionTask.defaultValueNoResponse {
                                values[i].append(String(response))
                            } else {
                                values[i].append("NaN")
                            }
                        } else {
                            values[i].append("NaN")
                        }
                    }

                    let coordinate = sceneTask.responseCoordinates
                    switch coordinate {
                    case .cartesian:
                        if let x = sceneTask.userResponses[i].xTouches.last,
                            let y = sceneTask.userResponses[i].yTouches.last {
                            values[i].append("\(x)")
                            values[i].append("\(y)")
                        } else {
                            values[i].append("NaN")
                            values[i].append("NaN")
                        }
                    case .polar:
                        if let radius = sceneTask.userResponses[i].radiusTouches.last,
                            let angle = sceneTask.userResponses[i].angleTouches.last {
                            values[i].append("\(radius)")
                            values[i].append("\(angle)")
                        } else {
                            values[i].append("NaN")
                            values[i].append("NaN")
                        }
                    }
                }
            case .twoFingersTouch:
                for i in 0 ..< respondedTrials {
                    var newValue = "NaN"

                    if let clock2 = sceneTask.userResponses[i].liftClock {
                        newValue = String(format: "%.4f", clock2)
                    } else if let clock = sceneTask.userResponses[i].clocks.last {
                        newValue = String(format: "%.4f", clock)
                    }
                    values[i].append(newValue)

                    if let response = sceneTask.userResponses[i].string {
                        values[i].append(response)
                    } else if sceneTask.isRealResponse {
                        if let response = Task.shared.sectionTask.defaultValueNoResponse {
                            values[i].append(String(response))
                        } else {
                            values[i].append("NaN")
                        }
                    } else {
                        values[i].append("NaN")
                    }

                    let coordinate = sceneTask.responseCoordinates
                    switch coordinate {
                    case .cartesian:
                        if let x = sceneTask.userResponses[i].xTouches.last,
                            let y = sceneTask.userResponses[i].yTouches.last,
                            let x2 = sceneTask.userResponses[i].xTouch2,
                            let y2 = sceneTask.userResponses[i].yTouch2 {
                            values[i].append("\(x)")
                            values[i].append("\(y)")
                            values[i].append("\(x2)")
                            values[i].append("\(y2)")
                        } else {
                            values[i].append("NaN")
                            values[i].append("NaN")
                            values[i].append("NaN")
                            values[i].append("NaN")
                        }
                    case .polar:
                        if let radius = sceneTask.userResponses[i].radiusTouches.last,
                            let angle = sceneTask.userResponses[i].angleTouches.last,
                            let radius2 = sceneTask.userResponses[i].radiusTouch2,
                            let angle2 = sceneTask.userResponses[i].angleTouch2 {
                            values[i].append("\(radius)")
                            values[i].append("\(angle)")
                            values[i].append("\(radius2)")
                            values[i].append("\(angle2)")
                        } else {
                            values[i].append("NaN")
                            values[i].append("NaN")
                            values[i].append("NaN")
                            values[i].append("NaN")
                        }
                    }
                }
            }
        }
        if includeRespondedInTime {
            for i in 0 ..< respondedTrials {
                values[i].append(String(respondedValue[i]))
            }
        }
        if includeCorrect {
            for i in 0 ..< respondedTrials {
                values[i].append(String(correctValue[i]))
            }
        }

        //titlesPath & titlesUnit
        for sceneTask in sceneTasks
            where sceneTask.responseType == .path || sceneTask.responseType == .moveObject {

                if titlesPath.isEmpty {
                    titlesPath.append("trial")
                }

                let coordinate = sceneTask.responseCoordinates
                let unit1 = sceneTask.responseFirstUnit
                let unit2 = sceneTask.responseSecondUnit

                switch coordinate {
                case .cartesian:
                    titlesPath.append("\(sceneTask.name)_positionsX")
                    titlesPath.append("\(sceneTask.name)_positionsY")
                    titlesPath.append("\(sceneTask.name)_times")

                    titlesUnit.append("\(sceneTask.name)_PositionsX (\(unit1.name))")
                    titlesUnit.append("\(sceneTask.name)_PositionsY (\(unit2.name))")
                    titlesUnit.append("\(sceneTask.name)_times (s)")

                case .polar:
                    titlesPath.append("\(sceneTask.name)_positionsRadius")
                    titlesPath.append("\(sceneTask.name)_positionsAngle")
                    titlesPath.append("\(sceneTask.name)_times")

                    titlesUnit.append("\(sceneTask.name)_positionsRadius (\(unit1.name))")
                    titlesUnit.append("\(sceneTask.name)_positionsAngle (\(unit2.name))")
                    titlesUnit.append("\(sceneTask.name)_times (s)")
                }
        }

        //valuesPath
        for sceneTask in sceneTasks
            where sceneTask.responseType == .path || sceneTask.responseType == .moveObject {

                if !titlesPath.isEmpty {
                    for i in 0 ..< respondedTrials {
                        let trial = String((i % numberOfTrials) + 1)
                        valuesPath.append([trial])
                    }
                }

                let coordinate = sceneTask.responseCoordinates

                switch coordinate {
                case .cartesian:
                    for i in 0 ..< respondedTrials {
                        let x = sceneTask.userResponses[i].xTouches.map({ String($0) }).joined(separator: ";")
                        let y = sceneTask.userResponses[i].yTouches.map({ String($0) }).joined(separator: ";")
                        let time = sceneTask.userResponses[i].clocks.map({
                            String(format: "%.4f", $0) }).joined(separator: ";")
                        valuesPath[i] += [x, y, time]
                    }
                case .polar:
                    for i in 0 ..< respondedTrials {
                        let radius = sceneTask.userResponses[i].radiusTouches.map({ String($0) }).joined(separator: ";")
                        let angle = sceneTask.userResponses[i].angleTouches.map({ String($0) }).joined(separator: ";")
                        let time = sceneTask.userResponses[i].clocks.map({
                            String(format: "%.4f", $0) }).joined(separator: ";")
                        valuesPath[i] += [radius, angle, time]
                    }
                }
        }

        let titlesString = titles.joined(separator: ",")

        let titlesUnitString = titlesUnit.joined(separator: "\n")

        var valuesFlat: [String] = []
        for i in 0 ..< respondedTrials {
            valuesFlat.append(values[i].joined(separator: ","))
        }
        let valuesString = valuesFlat.joined(separator: "\n")

        let titlesPathString = titlesPath.joined(separator: ",")

        var valuesPathFlat: [String] = []
        for i in 0 ..< valuesPath.count {
            valuesPathFlat.append(valuesPath[i].joined(separator: ","))
        }
        let valuesPathString = valuesPathFlat.joined(separator: "\n")

        let start = infoName + "\n\n" + titlesUnitString
        let csv0 = titlesString + "\n" + valuesString
        var csv1 = ""

        var result = start + "\n\n" + csv0

        if titlesPath.count != 0 {
            csv1 = titlesPathString + "\n" + valuesPathString
            result += "\n\n" + csv1
        }

        return SectionResult(result: result,
                             csv0: csv0,
                             csv0Name: name,
                             csv1: csv1,
                             csv1Name: name + "-trajectories")
    }
}
