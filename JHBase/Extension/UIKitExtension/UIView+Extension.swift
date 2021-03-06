//
//  File.swift
//  
//
//  Created by jh on 2022/1/13.
//

import UIKit

extension UIView: JHUIKitCompatible {}

// MARK: 2、手势的扩展
public extension JHUIKit where Base: UIView {
    // MARK: 2.1、通用响应添加方法
    /// 通用响应添加方法
    /// - Parameter actionClosure: 时间回调
    func addActionClosure(_ actionClosure: @escaping ViewClosure) {
        if let sender = self.base as? UIButton {
            sender.jh.setHandleClick(controlEvents: .touchUpInside) { (control) in
                guard let weakControl = control else {
                    return
                }
                actionClosure(nil, weakControl, weakControl.tag)
            }
        } else if let sender = self.base as? UIControl {
            sender.jh.addActionHandler({ (control) in
                actionClosure(nil, control, control.tag)
            }, for: .valueChanged)
        } else {
            _ = self.base.jh.addGestureTap { (reco) in
                actionClosure((reco as! UITapGestureRecognizer), reco.view!, reco.view!.tag)
            }
        }
    }
    
    // MARK: 2.2、手势 - 单击
    /// 手势 - 单击
    /// - Parameter action: 事件
    /// - Returns: 手势
    @discardableResult
    func addGestureTap(_ action: @escaping RecognizerClosure) -> UITapGestureRecognizer {
        let obj = UITapGestureRecognizer(target: nil, action: nil)
        // 轻点次数
        obj.numberOfTapsRequired = 1
        // 手指个数
        obj.numberOfTouchesRequired = 1
        addCommonGestureRecognizer(obj)
        obj.addAction { (recognizer) in
            action(recognizer)
        }
        return obj
    }
    
    //MARK: 通用支持手势的方法 - private
    private func addCommonGestureRecognizer(_ gestureRecognizer: UIGestureRecognizer) {
        base.isUserInteractionEnabled = true
        base.isMultipleTouchEnabled = true
        base.addGestureRecognizer(gestureRecognizer)
    }

}
