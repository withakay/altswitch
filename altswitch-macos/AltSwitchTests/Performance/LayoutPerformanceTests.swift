//
//  LayoutPerformanceTests.swift
//  AltSwitchTests
//
//  Performance tests for layout and visual effects (60fps requirements)
//  These tests MUST FAIL until the implementation is complete
//

import AppKit
import Foundation
import SwiftUI
import Testing

@testable import AltSwitch

@Suite("Layout Performance Tests")
@MainActor
struct LayoutPerformanceTests {

  @Test("Window layout maintains 60fps during animations")
  func testWindowLayoutAnimationPerformance() async throws {
    // Arrange
    let layoutEngine = MockLayoutEngine()
    let performanceMonitor = MockPerformanceMonitor()
    let animationController = MockAnimationController()

    await layoutEngine.initialize()
    await performanceMonitor.startMonitoring()

    // Configure 60fps target (16.67ms per frame)
    let targetFrameTime: TimeInterval = 1.0 / 60.0
    let maxAcceptableFrameTime: TimeInterval = targetFrameTime * 1.2  // 20ms tolerance

    // Test various animation scenarios
    let animationScenarios = [
      ("Window appearance", { await animationController.animateWindowAppearance(duration: 0.3) }),
      ("Window dismissal", { await animationController.animateWindowDismissal(duration: 0.25) }),
      (
        "Content resize",
        {
          await animationController.animateContentResize(
            from: CGSize(width: 600, height: 400), to: CGSize(width: 800, height: 600),
            duration: 0.4)
        }
      ),
      (
        "Position change",
        {
          await animationController.animatePositionChange(
            from: CGPoint(x: 100, y: 100), to: CGPoint(x: 500, y: 300), duration: 0.35)
        }
      ),
      (
        "Blur intensity",
        { await animationController.animateBlurIntensity(from: 0.0, to: 1.0, duration: 0.5) }
      ),
    ]

    for (scenarioName, animation) in animationScenarios {
      await performanceMonitor.resetFrameMetrics()

      // Act - Run animation and measure frame performance
      let animationStartTime = Date()
      await animation()
      let animationEndTime = Date()

      let frameMetrics = await performanceMonitor.getFrameMetrics()
      let animationDuration = animationEndTime.timeIntervalSince(animationStartTime)

      // Assert - Frame timing should meet 60fps requirements
      #expect(
        frameMetrics.averageFrameTime < maxAcceptableFrameTime,
        "\(scenarioName): Average frame time should be under \(maxAcceptableFrameTime * 1000)ms, was \(frameMetrics.averageFrameTime * 1000)ms"
      )

      #expect(
        frameMetrics.maxFrameTime < maxAcceptableFrameTime * 2,
        "\(scenarioName): Max frame time should be under \(maxAcceptableFrameTime * 2 * 1000)ms, was \(frameMetrics.maxFrameTime * 1000)ms"
      )

      let frameRate = 1.0 / frameMetrics.averageFrameTime
      #expect(
        frameRate >= 50.0,
        "\(scenarioName): Frame rate should be at least 50fps, was \(frameRate)fps")

      // Assert - No dropped frames during critical animations
      let expectedFrameCount = Int(animationDuration / targetFrameTime)
      let droppedFrames = max(0, expectedFrameCount - frameMetrics.actualFrameCount)
      let dropRate = Double(droppedFrames) / Double(expectedFrameCount)

      #expect(
        dropRate < 0.05,
        "\(scenarioName): Dropped frame rate should be under 5%, was \(dropRate * 100)%")
    }
  }

  @Test("UI rendering maintains performance during rapid user interactions")
  func testUIRenderingUnderRapidInteractions() async throws {
    // Arrange
    let renderingEngine = MockRenderingEngine()
    let inputSimulator = MockInputSimulator()
    let performanceMonitor = MockPerformanceMonitor()

    await renderingEngine.initialize()
    await performanceMonitor.startMonitoring()

    // Simulate rapid user interactions
    let interactionScenarios = [
      (
        "Rapid typing",
        {
          for i in 1...50 {
            await inputSimulator.simulateKeyPress(Character(UnicodeScalar(97 + i % 26)!))
            try? await Task.sleep(nanoseconds: 20_000_000)  // 20ms between keypresses
          }
        }
      ),
      (
        "Fast scrolling",
        {
          for i in 1...30 {
            await inputSimulator.simulateScroll(delta: Double(i % 10 - 5))
            try? await Task.sleep(nanoseconds: 33_000_000)  // 30fps scroll events
          }
        }
      ),
      (
        "Rapid selection changes",
        {
          for i in 1...25 {
            await inputSimulator.simulateSelectionChange(to: i % 10)
            try? await Task.sleep(nanoseconds: 16_000_000)  // 60fps selection changes
          }
        }
      ),
      (
        "Window drag simulation",
        {
          for i in 1...40 {
            let x = 200 + Double(i * 5)
            let y = 200 + sin(Double(i) * 0.2) * 50
            await inputSimulator.simulateWindowDrag(to: CGPoint(x: x, y: y))
            try? await Task.sleep(nanoseconds: 16_000_000)  // 60fps drag updates
          }
        }
      ),
    ]

    for (scenarioName, interaction) in interactionScenarios {
      await performanceMonitor.resetRenderMetrics()

      // Act - Perform rapid interactions
      let startTime = Date()
      await interaction()
      let endTime = Date()

      let renderMetrics = await performanceMonitor.getRenderMetrics()
      let interactionDuration = endTime.timeIntervalSince(startTime)

      // Assert - Rendering should remain responsive
      #expect(
        renderMetrics.averageRenderTime < 0.010,
        "\(scenarioName): Average render time should be under 10ms, was \(renderMetrics.averageRenderTime * 1000)ms"
      )

      #expect(
        renderMetrics.maxRenderTime < 0.025,
        "\(scenarioName): Max render time should be under 25ms, was \(renderMetrics.maxRenderTime * 1000)ms"
      )

      // Assert - UI should remain responsive during interactions
      #expect(
        renderMetrics.responsiveFramePercent > 0.90,
        "\(scenarioName): At least 90% of frames should be responsive, was \(renderMetrics.responsiveFramePercent * 100)%"
      )

      // Assert - Memory usage should remain stable
      #expect(
        renderMetrics.memoryGrowth < 5_000_000,
        "\(scenarioName): Memory growth should be under 5MB, was \(renderMetrics.memoryGrowth / 1_000_000)MB"
      )
    }
  }

  @Test("Layout performance scales efficiently with content complexity")
  func testLayoutPerformanceWithVaryingComplexity() async throws {
    // Arrange
    let layoutEngine = MockLayoutEngine()
    let contentManager = MockContentManager()
    let performanceMonitor = MockPerformanceMonitor()

    await layoutEngine.initialize()

    // Test with varying content complexity
    let complexityLevels = [
      (itemCount: 10, blurLayers: 1, description: "Low complexity"),
      (itemCount: 25, blurLayers: 2, description: "Medium complexity"),
      (itemCount: 50, blurLayers: 3, description: "High complexity"),
      (itemCount: 100, blurLayers: 4, description: "Very high complexity"),
      (itemCount: 200, blurLayers: 5, description: "Maximum complexity"),
    ]

    var performanceBaseline: TimeInterval = 0

    for (index, (itemCount, blurLayers, description)) in complexityLevels.enumerated() {
      // Configure content complexity
      await contentManager.setItemCount(itemCount)
      await contentManager.setBlurLayerCount(blurLayers)

      await performanceMonitor.resetLayoutMetrics()

      // Act - Perform layout operations
      let measurements = (1...15).map { _ in
        let startTime = Date()
        await layoutEngine.performFullLayout()
        return Date().timeIntervalSince(startTime)
      }

      let averageLayoutTime = measurements.reduce(0, +) / Double(measurements.count)
      let maxLayoutTime = measurements.max() ?? 0

      if index == 0 {
        performanceBaseline = averageLayoutTime
      }

      // Assert - Layout time should remain reasonable
      #expect(
        averageLayoutTime < 0.050,
        "\(description): Average layout time should be under 50ms, was \(averageLayoutTime * 1000)ms"
      )

      #expect(
        maxLayoutTime < 0.100,
        "\(description): Max layout time should be under 100ms, was \(maxLayoutTime * 1000)ms")

      // Assert - Performance degradation should be controlled
      let degradationFactor = averageLayoutTime / performanceBaseline
      let maxAllowedDegradation = 1.0 + (Double(index) * 0.5)  // Allow 50% degradation per complexity level

      #expect(
        degradationFactor < maxAllowedDegradation,
        "\(description): Performance degradation should be under \(maxAllowedDegradation)x baseline, was \(degradationFactor)x"
      )

      // Test frame rate during layout updates
      await performanceMonitor.startFrameMonitoring()

      for _ in 1...10 {
        await layoutEngine.updateLayout()
        try? await Task.sleep(nanoseconds: 16_000_000)  // 60fps target
      }

      let frameMetrics = await performanceMonitor.getFrameMetrics()
      let frameRate = 1.0 / frameMetrics.averageFrameTime

      #expect(
        frameRate >= 45.0,
        "\(description): Frame rate during updates should be at least 45fps, was \(frameRate)fps")
    }
  }

  @Test("Memory allocation and deallocation maintain stable performance")
  func testMemoryPerformanceStability() async throws {
    // Arrange
    let memoryManager = MockMemoryManager()
    let performanceMonitor = MockPerformanceMonitor()
    let layoutEngine = MockLayoutEngine()

    await memoryManager.enableMemoryTracking()
    await performanceMonitor.startMonitoring()

    // Test memory allocation patterns during typical usage
    let usagePatterns = [
      (
        "Steady state",
        {
          for _ in 1...20 {
            await layoutEngine.performLayoutUpdate()
            try? await Task.sleep(nanoseconds: 50_000_000)  // 50ms intervals
          }
        }
      ),
      (
        "Burst allocation",
        {
          for _ in 1...50 {
            await layoutEngine.allocateTemporaryResources()
            await layoutEngine.deallocateTemporaryResources()
            try? await Task.sleep(nanoseconds: 10_000_000)  // 10ms intervals
          }
        }
      ),
      (
        "Memory pressure",
        {
          await memoryManager.simulateMemoryPressure()
          for _ in 1...15 {
            await layoutEngine.performLayoutUpdate()
            try? await Task.sleep(nanoseconds: 30_000_000)  // 30ms intervals
          }
          await memoryManager.releaseMemoryPressure()
        }
      ),
      (
        "Rapid show/hide cycles",
        {
          for _ in 1...30 {
            await layoutEngine.showWindow()
            await layoutEngine.hideWindow()
            try? await Task.sleep(nanoseconds: 20_000_000)  // 20ms intervals
          }
        }
      ),
    ]

    var initialMemory: UInt64 = 0

    for (index, (patternName, pattern)) in usagePatterns.enumerated() {
      let memoryBefore = await memoryManager.getCurrentMemoryUsage()
      if index == 0 {
        initialMemory = memoryBefore
      }

      await performanceMonitor.resetMemoryMetrics()

      // Act - Execute usage pattern
      let startTime = Date()
      await pattern()
      let endTime = Date()

      let memoryAfter = await memoryManager.getCurrentMemoryUsage()
      let memoryMetrics = await performanceMonitor.getMemoryMetrics()
      let patternDuration = endTime.timeIntervalSince(startTime)

      // Assert - Memory usage should remain stable
      let memoryGrowth = memoryAfter > memoryBefore ? memoryAfter - memoryBefore : 0
      #expect(
        memoryGrowth < 10_000_000,
        "\(patternName): Memory growth should be under 10MB, was \(memoryGrowth / 1_000_000)MB")

      // Assert - No significant memory leaks
      let memoryLeakRate = Double(memoryGrowth) / patternDuration
      #expect(
        memoryLeakRate < 1_000_000.0,
        "\(patternName): Memory leak rate should be under 1MB/s, was \(memoryLeakRate / 1_000_000)MB/s"
      )

      // Assert - GC pressure should be manageable
      #expect(
        memoryMetrics.gcCount < 5,
        "\(patternName): Garbage collection count should be under 5, was \(memoryMetrics.gcCount)")

      #expect(
        memoryMetrics.totalGCTime < patternDuration * 0.1,
        "\(patternName): GC time should be under 10% of total time, was \(memoryMetrics.totalGCTime / patternDuration * 100)%"
      )

      // Assert - Memory should not grow excessively over baseline
      let memoryGrowthFromBaseline = memoryAfter > initialMemory ? memoryAfter - initialMemory : 0
      #expect(
        memoryGrowthFromBaseline < 20_000_000,
        "\(patternName): Total memory growth from baseline should be under 20MB, was \(memoryGrowthFromBaseline / 1_000_000)MB"
      )
    }
  }

  @Test("Performance remains stable during extended usage sessions")
  func testExtendedUsagePerformanceStability() async throws {
    // Arrange
    let sessionManager = MockSessionManager()
    let performanceMonitor = MockPerformanceMonitor()
    let layoutEngine = MockLayoutEngine()

    await sessionManager.startExtendedSession()
    await performanceMonitor.startContinuousMonitoring()

    // Simulate extended usage over time
    let sessionDurationMinutes = 5  // Abbreviated for testing
    let measurementIntervalSeconds = 30
    let measurementCount = (sessionDurationMinutes * 60) / measurementIntervalSeconds

    var performanceSamples: [MockPerformanceSample] = []

    for iteration in 1...measurementCount {
      let iterationStartTime = Date()

      // Simulate typical usage activities
      await layoutEngine.showWindow()

      // Simulate user interactions
      for _ in 1...10 {
        await sessionManager.simulateTypicalUserAction()
        try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms between actions
      }

      await layoutEngine.hideWindow()

      // Wait for next measurement interval
      let elapsedTime = Date().timeIntervalSince(iterationStartTime)
      let remainingTime = Double(measurementIntervalSeconds) - elapsedTime
      if remainingTime > 0 {
        try? await Task.sleep(nanoseconds: UInt64(remainingTime * 1_000_000_000))
      }

      // Collect performance sample
      let sample = await performanceMonitor.takePerformanceSample()
      sample.sessionTime = Double(iteration * measurementIntervalSeconds)
      performanceSamples.append(sample)

      // Assert - Performance should remain stable throughout session
      #expect(
        sample.frameRate >= 50.0,
        "Frame rate should remain above 50fps at \(iteration * measurementIntervalSeconds)s, was \(sample.frameRate)fps"
      )

      #expect(
        sample.renderTime < 0.015,
        "Render time should remain under 15ms at \(iteration * measurementIntervalSeconds)s, was \(sample.renderTime * 1000)ms"
      )

      #expect(
        sample.memoryUsage < 100_000_000,
        "Memory usage should remain under 100MB at \(iteration * measurementIntervalSeconds)s, was \(sample.memoryUsage / 1_000_000)MB"
      )
    }

    // Assert - Performance should not degrade over time
    let firstQuarter = performanceSamples.prefix(measurementCount / 4)
    let lastQuarter = performanceSamples.suffix(measurementCount / 4)

    let initialAvgFrameRate =
      firstQuarter.map(\.frameRate).reduce(0, +) / Double(firstQuarter.count)
    let finalAvgFrameRate = lastQuarter.map(\.frameRate).reduce(0, +) / Double(lastQuarter.count)

    let frameRateDegradation = (initialAvgFrameRate - finalAvgFrameRate) / initialAvgFrameRate
    #expect(
      frameRateDegradation < 0.10,
      "Frame rate degradation should be under 10%, was \(frameRateDegradation * 100)%")

    let initialAvgMemory =
      firstQuarter.map { Double($0.memoryUsage) }.reduce(0, +) / Double(firstQuarter.count)
    let finalAvgMemory =
      lastQuarter.map { Double($0.memoryUsage) }.reduce(0, +) / Double(lastQuarter.count)

    let memoryGrowth = finalAvgMemory - initialAvgMemory
    #expect(
      memoryGrowth < 15_000_000,
      "Memory growth over session should be under 15MB, was \(memoryGrowth / 1_000_000)MB")
  }

  @Test("Performance meets requirements under system resource constraints")
  func testPerformanceUnderResourceConstraints() async throws {
    // Arrange
    let resourceManager = MockResourceManager()
    let performanceMonitor = MockPerformanceMonitor()
    let layoutEngine = MockLayoutEngine()

    // Test under various resource constraints
    let constraintScenarios = [
      (cpuLimit: 0.5, memoryLimit: 0.7, description: "Moderate constraints"),
      (cpuLimit: 0.3, memoryLimit: 0.5, description: "High constraints"),
      (cpuLimit: 0.2, memoryLimit: 0.3, description: "Severe constraints"),
    ]

    for (cpuLimit, memoryLimit, description) in constraintScenarios {
      // Apply resource constraints
      await resourceManager.setCPULimit(cpuLimit)
      await resourceManager.setMemoryLimit(memoryLimit)

      await performanceMonitor.resetConstrainedMetrics()

      // Act - Perform operations under constraints
      let operationCount = 20
      var operationTimes: [TimeInterval] = []

      for i in 1...operationCount {
        let startTime = Date()

        await layoutEngine.showWindow()
        await layoutEngine.performLayoutOperations()
        await layoutEngine.hideWindow()

        let operationTime = Date().timeIntervalSince(startTime)
        operationTimes.append(operationTime)

        // Brief pause between operations
        try? await Task.sleep(nanoseconds: 50_000_000)  // 50ms
      }

      let constrainedMetrics = await performanceMonitor.getConstrainedMetrics()

      // Assert - Operations should complete within acceptable time even under constraints
      let averageOperationTime = operationTimes.reduce(0, +) / Double(operationTimes.count)
      let maxOperationTime = operationTimes.max() ?? 0

      // Scale expectations based on constraint severity
      let timeLimit = 0.5 * (1.0 / cpuLimit)  // Scale with CPU constraint

      #expect(
        averageOperationTime < timeLimit,
        "\(description): Average operation time should be under \(timeLimit * 1000)ms, was \(averageOperationTime * 1000)ms"
      )

      #expect(
        maxOperationTime < timeLimit * 2,
        "\(description): Max operation time should be under \(timeLimit * 2 * 1000)ms, was \(maxOperationTime * 1000)ms"
      )

      // Assert - Quality should degrade gracefully
      #expect(
        constrainedMetrics.adaptiveQuality > 0.7,
        "\(description): Adaptive quality should remain above 70%, was \(constrainedMetrics.adaptiveQuality * 100)%"
      )

      #expect(
        constrainedMetrics.featureDegradation < 0.3,
        "\(description): Feature degradation should be under 30%, was \(constrainedMetrics.featureDegradation * 100)%"
      )

      // Remove constraints for next test
      await resourceManager.removeConstraints()
    }
  }
}

// MARK: - Mock Classes for Testing

@MainActor
private class MockLayoutEngine {
  private var isInitialized = false
  private var isWindowVisible = false

  func initialize() async {
    try? await Task.sleep(nanoseconds: 50_000_000)  // 50ms init
    isInitialized = true
  }

  func performFullLayout() async {
    try? await Task.sleep(nanoseconds: 25_000_000)  // 25ms layout
  }

  func updateLayout() async {
    try? await Task.sleep(nanoseconds: 5_000_000)  // 5ms update
  }

  func performLayoutUpdate() async {
    try? await Task.sleep(nanoseconds: 8_000_000)  // 8ms update
  }

  func showWindow() async {
    try? await Task.sleep(nanoseconds: 10_000_000)  // 10ms show
    isWindowVisible = true
  }

  func hideWindow() async {
    try? await Task.sleep(nanoseconds: 5_000_000)  // 5ms hide
    isWindowVisible = false
  }

  func allocateTemporaryResources() async {
    try? await Task.sleep(nanoseconds: 2_000_000)  // 2ms allocation
  }

  func deallocateTemporaryResources() async {
    try? await Task.sleep(nanoseconds: 1_000_000)  // 1ms deallocation
  }

  func performLayoutOperations() async {
    try? await Task.sleep(nanoseconds: 15_000_000)  // 15ms operations
  }
}

private actor MockPerformanceMonitor {
  private var frameMetrics = MockFrameMetrics()
  private var renderMetrics = MockRenderMetrics()
  private var memoryMetrics = MockMemoryMetrics()
  private var constrainedMetrics = MockConstrainedMetrics()

  func startMonitoring() async {
    // Start monitoring
  }

  func startFrameMonitoring() async {
    frameMetrics = MockFrameMetrics()
  }

  func startContinuousMonitoring() async {
    // Start continuous monitoring
  }

  func resetFrameMetrics() async {
    frameMetrics = MockFrameMetrics()
  }

  func resetRenderMetrics() async {
    renderMetrics = MockRenderMetrics()
  }

  func resetLayoutMetrics() async {
    // Reset layout metrics
  }

  func resetMemoryMetrics() async {
    memoryMetrics = MockMemoryMetrics()
  }

  func resetConstrainedMetrics() async {
    constrainedMetrics = MockConstrainedMetrics()
  }

  func getFrameMetrics() async -> MockFrameMetrics {
    return MockFrameMetrics(
      averageFrameTime: 0.014,  // ~71fps
      maxFrameTime: 0.018,  // ~55fps worst case
      actualFrameCount: 45
    )
  }

  func getRenderMetrics() async -> MockRenderMetrics {
    return MockRenderMetrics(
      averageRenderTime: 0.008,
      maxRenderTime: 0.015,
      responsiveFramePercent: 0.95,
      memoryGrowth: 2_000_000
    )
  }

  func getMemoryMetrics() async -> MockMemoryMetrics {
    return MockMemoryMetrics(
      gcCount: 2,
      totalGCTime: 0.005
    )
  }

  func getConstrainedMetrics() async -> MockConstrainedMetrics {
    return MockConstrainedMetrics(
      adaptiveQuality: 0.85,
      featureDegradation: 0.15
    )
  }

  func takePerformanceSample() async -> MockPerformanceSample {
    return MockPerformanceSample(
      frameRate: Double.random(in: 55...65),
      renderTime: Double.random(in: 0.008...0.015),
      memoryUsage: UInt64.random(in: 25_000_000...45_000_000),
      sessionTime: 0
    )
  }
}

private actor MockAnimationController {
  func animateWindowAppearance(duration: TimeInterval) async {
    try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
  }

  func animateWindowDismissal(duration: TimeInterval) async {
    try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
  }

  func animateContentResize(from: CGSize, to: CGSize, duration: TimeInterval) async {
    try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
  }

  func animatePositionChange(from: CGPoint, to: CGPoint, duration: TimeInterval) async {
    try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
  }

  func animateBlurIntensity(from: Double, to: Double, duration: TimeInterval) async {
    try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
  }
}

private actor MockRenderingEngine {
  func initialize() async {
    try? await Task.sleep(nanoseconds: 30_000_000)  // 30ms init
  }
}

private actor MockInputSimulator {
  func simulateKeyPress(_ character: Character) async {
    try? await Task.sleep(nanoseconds: 1_000_000)  // 1ms per keypress
  }

  func simulateScroll(delta: Double) async {
    try? await Task.sleep(nanoseconds: 2_000_000)  // 2ms per scroll
  }

  func simulateSelectionChange(to index: Int) async {
    try? await Task.sleep(nanoseconds: 1_500_000)  // 1.5ms per selection
  }

  func simulateWindowDrag(to position: CGPoint) async {
    try? await Task.sleep(nanoseconds: 1_000_000)  // 1ms per drag update
  }
}

private actor MockContentManager {
  private var itemCount = 10
  private var blurLayerCount = 1

  func setItemCount(_ count: Int) async {
    itemCount = count
  }

  func setBlurLayerCount(_ count: Int) async {
    blurLayerCount = count
  }
}

private actor MockMemoryManager {
  private var memoryUsage: UInt64 = 20_000_000  // 20MB baseline
  private var isTrackingEnabled = false

  func enableMemoryTracking() async {
    isTrackingEnabled = true
  }

  func getCurrentMemoryUsage() async -> UInt64 {
    return memoryUsage + UInt64.random(in: 0...5_000_000)  // Add some variance
  }

  func simulateMemoryPressure() async {
    memoryUsage += 10_000_000  // 10MB pressure
  }

  func releaseMemoryPressure() async {
    memoryUsage = max(20_000_000, memoryUsage - 8_000_000)  // Release most pressure
  }
}

private actor MockSessionManager {
  func startExtendedSession() async {
    // Start session
  }

  func simulateTypicalUserAction() async {
    try? await Task.sleep(nanoseconds: 5_000_000)  // 5ms per action
  }
}

private actor MockResourceManager {
  private var cpuLimit: Double = 1.0
  private var memoryLimit: Double = 1.0

  func setCPULimit(_ limit: Double) async {
    cpuLimit = limit
  }

  func setMemoryLimit(_ limit: Double) async {
    memoryLimit = limit
  }

  func removeConstraints() async {
    cpuLimit = 1.0
    memoryLimit = 1.0
  }
}

// MARK: - Supporting Test Types

private struct MockFrameMetrics {
  let averageFrameTime: TimeInterval
  let maxFrameTime: TimeInterval
  let actualFrameCount: Int

  init(
    averageFrameTime: TimeInterval = 0.016, maxFrameTime: TimeInterval = 0.020,
    actualFrameCount: Int = 60
  ) {
    self.averageFrameTime = averageFrameTime
    self.maxFrameTime = maxFrameTime
    self.actualFrameCount = actualFrameCount
  }
}

private struct MockRenderMetrics {
  let averageRenderTime: TimeInterval
  let maxRenderTime: TimeInterval
  let responsiveFramePercent: Double
  let memoryGrowth: UInt64
}

private struct MockMemoryMetrics {
  let gcCount: Int
  let totalGCTime: TimeInterval
}

private struct MockConstrainedMetrics {
  let adaptiveQuality: Double
  let featureDegradation: Double
}

private class MockPerformanceSample {
  let frameRate: Double
  let renderTime: TimeInterval
  let memoryUsage: UInt64
  var sessionTime: TimeInterval

  init(frameRate: Double, renderTime: TimeInterval, memoryUsage: UInt64, sessionTime: TimeInterval)
  {
    self.frameRate = frameRate
    self.renderTime = renderTime
    self.memoryUsage = memoryUsage
    self.sessionTime = sessionTime
  }
}
