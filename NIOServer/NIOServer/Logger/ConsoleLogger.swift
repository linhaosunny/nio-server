//
//  ConsoleLogger.swift
//  NIOServer
//
//  Created by lishaxin on 2024/7/3.
//

import UIKit
import Logging

public typealias logger = ConsoleLogger

/// class
public class ConsoleLogger {
    
    /// enum
    public enum Channel: CaseIterable {
        case `default`
        /// var
        var logger: Logger {
            switch self {
            case .default:
                return ConsoleLogger.shared.logger
            }
        }
    }
    
    /// shared
    static let shared = ConsoleLogger()
    
    /// 指示是否启用日志记录，默认为 `true`。
    private static var isEnabled: Bool = true
    
    /// 允许记录的日志级别列表。
    /// 默认情况下，允许所有级别。
    private static var allowedLevels: [Logger.Level] = [.trace, .debug, .info, .notice, .warning, .error, .critical]
    
    /// 当添加新日志时触发的回调函数。
    /// 它传递更新后包含日志的 `NSMutableAttributedString`。
    private static var didAddLog: ((NSMutableAttributedString) -> Void)?
    
    /// 累积格式化日志条目的 `NSMutableAttributedString`。
    private static var logAttrString = NSMutableAttributedString()
    
    /// UUID
    /// 生成一个新的 UUID 字符串。
    private static var uniqueIdentifier: String {
        return UUID().uuidString
    }
    
    /// 默认Logger
    lazy var logger = Logger(label: "defalut")
    /// 执行的串行队列
    var query = DispatchQueue(label: "com.logger")
    /// 默认启用所有通道
    var enableChannel = ConsoleLogger.Channel.allCases
    
    /// init
    private init() {
        // logLevel
        self.logger.logLevel = .debug
        // query async
        query.async {
            self.enableChannel.forEach({ self.set(level: .debug, to: $0) })
        }
    }
    
    /// set
    func set(level: Logger.Level, to channel: Channel) {
        query.async {
            switch channel {
            case .default:
                self.logger.logLevel = level
            }
        }
    }
}

// MARK: - init
extension ConsoleLogger {
    
    /// setup
    public static func setup(enabled: Bool = true, allowedLogLevels: [Logger.Level] = [.trace, .debug, .info, .notice, .warning, .error, .critical]) {
        // set
        isEnabled = enabled
        allowedLevels = allowedLogLevels
    }
    
    /// 清除日志属性字符串
    public static func clear() {
        logAttrString = NSMutableAttributedString()
    }
    
    /// 是否启用日志记录
    public static var isLogEnabled: Bool {
        get {
            return isEnabled
        }
        set {
            isEnabled = newValue
        }
    }
    
    /// 允许的日志级别
    public static var allowedLogLevels: [Logger.Level] {
        get {
            return allowedLevels
        }
        set {
            allowedLevels = newValue
        }
    }
    
    /// 添加日志回调
    public static func setDidAddLogCallback(_ callback: ((NSMutableAttributedString) -> Void)?) {
        didAddLog = callback
    }
}

// MARK: - public
extension ConsoleLogger {
    
    /// 打印调试信息
    public static func debugLog(_ items: Any...) {
#if DEBUG
        // 检查是否启用了日志记录
        guard self.isEnabled else { return }
        // output
        let output = items.map { "\($0)" }.joined(separator: " ")
        print(output)
#endif
    }
    
    /// info 默认启用等级，方法调用
    public static func info(_ items: Any?..., channel: Channel = .default, file: String = #file, function: StaticString = #function, line: Int = #line) {
        ConsoleLogger.log(items, level: .info, channel: channel, file: file, function: function, line: line)
    }
    /// debug 内容需要包含当前上下文的数据时
    public static func debug(_ items: Any?..., channel: Channel = .default, file: String = #file, function: StaticString = #function, line: Int = #line) {
        ConsoleLogger.log(items, level: .debug, channel: channel, file: file, function: function, line: line)
    }
    /// warning 潜在问题时
    public static func warning(_ items: Any?..., channel: Channel = .default, file: String = #file, function: StaticString = #function, line: Int = #line) {
        ConsoleLogger.log(items, level: .warning, channel: channel, file: file, function: function, line: line)
    }
    /// error 出错时
    public static func error(_ items: Any?..., channel: Channel = .default, file: String = #file, function: StaticString = #function, line: Int = #line) {
        ConsoleLogger.log(items, level: .error, channel: channel, file: file, function: function, line: line)
    }
    /// debugCustom
    public static func debugCustom(_ items: [Any?], level: Logger.Level = .debug, channel: Channel = .default, file: String, function: StaticString, line: Int) {
        ConsoleLogger.log(items, level: level, channel: channel, file: file, function: function, line: line)
    }
}

// MARK: - private
extension ConsoleLogger {
    
    /// 根据给定的级别和通道记录消息，包括文件名、函数和行号信息
    private static func log(_ items: [Any?], level: Logger.Level, channel: Channel = .default, file: String, function: StaticString, line: Int) {
#if DEBUG
        // 检查是否启用了日志记录并且当前级别是否在允许的级别中
        guard self.isEnabled, allowedLevels.contains(level) else { return }
        // 从提供的条目构造消息
        let message = message(from: items)
        // 确保通道启用后再继续
        guard ConsoleLogger.shared.enableChannel.contains(channel) else {
            return
        }
        // 获取线程信息
        let threadStr = Thread.isMainThread ? "主线程" : "非主线程"
        // 在指定队列上异步执行日志记录
        ConsoleLogger.shared.query.async {
            // 构造日志级别字符串
            let levelStr = "[\(level.rawValue.uppercased())]"
            // 构造完整的日志消息，确保以换行符结束
            let messageWithNewLine = message.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
            // 使用emoji和级别字符串格式化消息
            let formattedMessage = level.emoji + levelStr + " " + messageWithNewLine
            // 获取文件名
            let fileName = URL(fileURLWithPath: file).lastPathComponent
            // 获取格式化的日期字符串
            let dateString = Date().YYYYMMDDHHMMssSSSDateText
            // 拼接最终的日志消息
            let logMessage = "\(dateString) \(fileName):\(line) \(function): \(threadStr): \(formattedMessage)"
            
            // 获取对应通道的Logger实例
            var logger: Logger = channel.logger
            // 设置请求UUID
            logger[metadataKey: "request-uuid"] = "\(uniqueIdentifier)"
            // 记录日志
            logger.log(level: level, "\(logMessage)")
            
            // 回调和UI更新需要在主线程上执行
            DispatchQueue.main.async {
                // 更新富文本日志
                ConsoleLogger.updateLogAttributedString(with: logMessage, level: level)
                // 执行回调
                ConsoleLogger.didAddLog?(logAttrString)
            }
        }
#endif
    }
    
    /// 更新富文本日志字符串
    private static func updateLogAttributedString(with logString: String, level: Logger.Level) {
        let attributedString = handleLog(logString, level: level)
        if logAttrString.length == 0 {
            logAttrString = NSMutableAttributedString(attributedString: attributedString)
        } else {
            logAttrString.append(attributedString)
        }
        // 如果日志长度超过一定阈值，则清理
        clearLogAttributedStringIfNeeded()
    }
    
    /// 清理日志属性字符串，如果长度超过阈值
    private static func clearLogAttributedStringIfNeeded() {
        let maxLength = 10000 // 设置一个最大长度，根据需要调整
        if logAttrString.length > maxLength {
            clear()
        }
    }
    
    /// 从提供的日志条目中构造单个字符串
    private static func message(from items: [Any?]) -> String {
        return items
            .compactMap { $0 }
            .map { String(describing: $0) }
            .joined(separator: " ")
    }
    
    /// 将日志消息格式化为属性字符串，并根据日志级别设置颜色
    private static func handleLog(_ message: String, level: Logger.Level) -> NSAttributedString {
        let color = self.color(for: level) // 获取颜色
        let aStr = NSMutableAttributedString(string: message)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 2
        
        // 设置属性
        aStr.addAttributes([
            NSAttributedString.Key.paragraphStyle: paragraphStyle,
            NSAttributedString.Key.foregroundColor: color // 使用颜色
        ], range: NSRange(location: 0, length: message.count))
        
        return aStr
    }
    
    /// 返回与特定日志级别关联的颜色
    private static func color(for level: Logger.Level) -> UIColor {
        switch level {
        case .trace:
            return .darkGray
        case .debug:
            return .green
        case .info:
            return .blue
        case .notice:
            return .yellow
        case .warning:
            return .yellow
        case .error:
            return .orange
        case .critical:
            return .red
        }
    }
}

// MARK: - Level
/// Level
extension Logger.Level {
    var emoji: String {
        switch self {
        case .trace:
            return "🐳"
        case .debug:
            return "❇️"
        case .info:
            return "💎"
        case .notice:
            return "⚠️"
        case .warning:
            return "⚠️"
        case .error:
            return "❌"
        case .critical:
            return "❌❌"
        }
    }
}

extension Date {
    /// static
    static let yyyyMMddHHmmssSSS = "yyyy-MM-dd HH:mm:ss SSSS"
    static var dateFormatter: DateFormatter = DateFormatter()
    /// static
    var YYYYMMDDHHMMssSSSDateText: String {
        Date.dateFormatter.dateFormat = Date.yyyyMMddHHmmssSSS
        return Date.dateFormatter.string(from: self)
    }
    
}
