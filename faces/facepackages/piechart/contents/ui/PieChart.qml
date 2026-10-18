/*
    SPDX-FileCopyrightText: 2019 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2019 David Edmundson <davidedmundson@kde.org>
    SPDX-FileCopyrightText: 2019 Arjen Hiemstra <ahiemstra@heimr.nl>
    SPDX-FileCopyrightText: 2019 Kai Uwe Broulik <kde@broulik.de>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

import org.kde.ksysguard.sensors as Sensors
import org.kde.ksysguard.faces as Faces

import org.kde.quickcharts as Charts
import org.kde.quickcharts.controls as ChartControls


ChartControls.PieChartControl {
    id: chart

    property alias headingSensor: sensor.sensorId
    property alias sensors: sensorsModel.sensors
    property alias sensorsModel: sensorsModel

    property int updateRateLimit

    Layout.minimumHeight: root.formFactor == Faces.SensorFace.Vertical ? width : Kirigami.Units.gridUnit

    leftPadding: 0
    rightPadding: 0
    topPadding: 0
    bottomPadding: 0

    readonly property real rangeFrom: root.controller.faceConfiguration.rangeFrom *
                                      root.controller.faceConfiguration.rangeFromMultiplier

    readonly property real rangeTo: root.controller.faceConfiguration.rangeTo *
                                    root.controller.faceConfiguration.rangeToMultiplier

    chart.smoothEnds: root.controller.faceConfiguration.smoothEnds
    chart.fromAngle: root.controller.faceConfiguration.fromAngle
    chart.toAngle: root.controller.faceConfiguration.toAngle
    chart.thickness: Kirigami.Units.largeSpacing

    range {
        from: chart.rangeFrom
        to: chart.rangeTo
        automatic: root.controller.faceConfiguration.rangeAuto
    }

    chart.backgroundColor: Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.1)

    valueSources: Charts.ModelSource {
        model: Sensors.SensorDataModel {
            id: sensorsModel
            sensors: root.controller.highPrioritySensorIds
            updateRateLimit: chart.updateRateLimit
            sensorLabels: root.controller.sensorLabels
        }
        roleName: "Value"
        indexColumns: true
    }
    chart.nameSource: Charts.ModelSource {
        roleName: "Name";
        model: valueSources[0].model;
        indexColumns: true
    }
    chart.shortNameSource: Charts.ModelSource {
        roleName: "ShortName";
        model: valueSources[0].model;
        indexColumns: true
    }
    chart.colorSource: root.controller.faceConfiguration.flashAboveThreshold ? flashColorSource : root.colorSource

    // Percentage of the data range above which the face flashes red.
    readonly property real flashThreshold: root.controller.faceConfiguration.flashThreshold
    property bool flashOn: false
    readonly property color flashTextColor: flashOn ? "white" : Kirigami.Theme.textColor
    property var overThreshold: []

    function percentOf(value, from, to) {
        return to > from ? (value - from) / (to - from) * 100 : 0
    }

    function updateOverThreshold() {
        if (!root.controller.faceConfiguration.flashAboveThreshold) {
            overThreshold = []
            return
        }
        // The value shown in the centre decides when there is one, so a full but
        // secondary sensor (e.g. a small swap) does not trigger the warning.
        if (sensor.sensorId) {
            const over = percentOf(sensor.value, sensor.minimum, sensor.maximum) >= chart.flashThreshold
            overThreshold = root.controller.highPrioritySensorIds.map(() => over)
            return
        }
        const over = []
        for (let i = 0; i < thresholdSensors.count; ++i) {
            const sensor = thresholdSensors.objectAt(i)
            // With an automatic range each sensor is measured against its own maximum.
            const from = range.automatic ? sensor.minimum : chart.rangeFrom
            const to = range.automatic ? sensor.maximum : chart.rangeTo
            over.push(chart.percentOf(sensor.value, from, to) >= chart.flashThreshold)
        }
        overThreshold = over
    }

    Instantiator {
        id: thresholdSensors
        active: root.controller.faceConfiguration.flashAboveThreshold
        model: root.controller.highPrioritySensorIds
        delegate: Sensors.Sensor {
            sensorId: modelData
            updateRateLimit: chart.updateRateLimit
            onValueChanged: chart.updateOverThreshold()
            onMetaDataChanged: chart.updateOverThreshold()
        }
        onObjectAdded: chart.updateOverThreshold()
        onObjectRemoved: chart.updateOverThreshold()
    }
    onFlashThresholdChanged: updateOverThreshold()
    readonly property bool flashEnabled: root.controller.faceConfiguration.flashAboveThreshold
    onFlashEnabledChanged: updateOverThreshold()
    onRangeFromChanged: updateOverThreshold()
    onRangeToChanged: updateOverThreshold()

    Timer {
        interval: 250
        repeat: true
        running: chart.overThreshold.includes(true)
        onRunningChanged: chart.flashOn = running
        onTriggered: chart.flashOn = !chart.flashOn
    }

    Charts.ArraySource {
        id: flashColorSource
        array: root.controller.highPrioritySensorIds.map((sensorId, i) =>
            chart.flashOn && chart.overThreshold[i] ? "white" : root.controller.sensorColors[sensorId])
    }

    Sensors.Sensor {
        id: sensor
        sensorId: root.controller.totalSensors.length > 0 ? root.controller.totalSensors[0] : ""
        updateRateLimit: chart.updateRateLimit
        onValueChanged: chart.updateOverThreshold()
        onMetaDataChanged: chart.updateOverThreshold()
    }

    UsedTotalDisplay {
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height)
        height: width

        usedSensor: root.controller.totalSensors.length > 0 ? root.controller.totalSensors[0] : ""
        totalSensor: root.controller.totalSensors.length > 1 ? root.controller.totalSensors[1] : ""

        contentMargin: chart.chart.thickness
        updateRateLimit: chart.updateRateLimit
    }
}
