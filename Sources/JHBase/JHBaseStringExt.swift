//
//  File.swift
//  
//
//  Created by lifei on 2021/9/1.
//  String 便利方法

import Foundation

extension String {
    public var boolValue: Bool {
        let strLower = self.lowercased()
        let strInt = Int(self) ?? 0
        if strLower == "true" || strLower == "yes" || strInt > 0{
            return true
        }
        return false
    }
    
    public var doubleValue: Double {
        return Double(self) ?? 0
    }
    
    public var floatValue: Float {
        return Float(self) ?? 0
    }
    
    public var intValue: Int {
        return Int(self) ?? 0
    }
}

// MARK: - String to NSObjct
extension String {
    
    public var toNSClass: NSObject.Type? {
        if self.isEmpty {
            return nil
        }
        guard let objCls = NSClassFromString(self).self as? NSObject.Type else { return nil }
        return objCls
    }
    
    public var toNSObject: NSObject? {
        guard let objCls = self.toNSClass else { return nil }
        return objCls.init()
    }
}

extension String {
    /// 搜索字符串中的位置
    /// - Parameters:
    ///   - subString: 子字符串
    ///   - ignoreCase: 是否忽略大小写
    /// - Returns: 子字符串的位置 NSRange
    public func getNSRange(of subString: String, _ caseInsensitive: Bool = false) -> NSRange? {
        if self.contains(subString) == false {
            return nil
        }
        let tmpStr = self as NSString
        var tmpRange = tmpStr.range(of: subString)
        if caseInsensitive == true {
            tmpRange = tmpStr.range(of: subString, options: .caseInsensitive)
        }
        return tmpRange
    }
}
