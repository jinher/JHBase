//  Created by lifei on 2021/12/7.
//  网络请求封装层

import Foundation
import Alamofire

public let JN = JHBaseNetwork.shared

public class JHBaseNetwork {
    public static let shared = JHBaseNetwork()
    private var taskList: [JHBaseNetworkRequest] = []
    
    // MARK: - API
    @discardableResult
    public func post(_ url: String,
                     parameters: [String: Any]? = nil,
                     headers: [String: String]? = nil) -> JHBaseNetworkRequest {
        request(url: url, method: .post, parameters: parameters, headers: headers, encoding: JSONEncoding.default)
    }
    
    @discardableResult
    public func get(_ url: String,
                    parameters: [String: Any]? = nil,
                    headers: [String: String]? = nil) -> JHBaseNetworkRequest {
        request(url: url, method: .get, parameters: parameters, headers: headers, encoding: URLEncoding.default)
    }
    
    @discardableResult
    public func download(_ url: String) -> JHBaseNetworkRequest {
        downloadFile(url)
    }
    
    public func download(_ urls: [String], _ completionHandler: @escaping ([String: String]) -> Void) {
        DispatchQueue(label: "com.jhbase.network").async {
            self.downloadFiles(urls, completionHandler)
        }
    }
    
    @discardableResult
    public func upload(_ data: Data,
                       url: String,
                       headers: [String: String]? = nil) -> JHBaseNetworkRequest {
        uploadFile(data, url: url, headers: headers)
    }
    
    public func cancelAll() {
        taskList.forEach { $0.cancel() }
    }
    
    // MARK: - Lazy Load
    private lazy var clientInfoDict: [String: Any] = {
        let fileURL = Bundle.main.url(forResource: "JHVersion", withExtension: "plist")
        guard let tmpFileURL = fileURL else { return [:] }
        let fileDict = try? NSDictionary(contentsOf: tmpFileURL, error: ())
        guard let fileDict = fileDict as? [String: Any] else { return [:] }
        guard let clientDict = fileDict["clientInfo"] as? [String: Any] else { return [:] }
        return clientDict
    }()
}

// MARK: - Private
extension JHBaseNetwork {
    private func request(url: String,
                         method: HTTPMethod = .get,
                         parameters: [String: Any]? = nil,
                         headers: [String: String]? = nil,
                         encoding: ParameterEncoding = URLEncoding.default) -> JHBaseNetworkRequest {
        let task = JHBaseNetworkRequest()
        
        var httpHeaders: HTTPHeaders? = nil
        if var headersDict = headers {
            if headersDict.index(forKey: "Content-Type") == nil {
                headersDict["Content-Type"] = "application/json; charset=utf-8"
            }
            if headersDict.index(forKey: "Accept") == nil {
                headersDict["Accept"] = "application/json"
            }
            httpHeaders = HTTPHeaders(headersDict)
        }
        // 增加 clientInfo 公共参数
        var paramDict: [String: Any] = parameters ?? [:]
        if method != .get {
            let clientDict: [String: Any] = readClientInfoDict()
            paramDict["clientInfo"] = clientDict
        }
        weak var weakTask = task
        task.request = AF.request(url,
                                  method: method,
                                  parameters: paramDict,
                                  encoding: encoding,
                                  headers: httpHeaders).validate().response
        { [weak self] resp in
            guard let strongTask = weakTask, let strongSelf = self else { return }
            strongTask.handleResponse(data: resp.data, error: resp.error, response: resp.response)
            strongSelf.taskList.removeFirst(where: { $0 == strongTask })
        }
        taskList.append(task)
        return task
    }
    
    private func downloadFile(_ url: String) -> JHBaseNetworkRequest {
        let task = JHBaseNetworkRequest()
        weak var weakTask = task
        
        task.request = AF.download(url).downloadProgress { progress in
            guard let strongTask = weakTask else { return }
            strongTask.handleProgress(progress: progress)
        }.validate().responseData { [weak self] resp in
            guard let strongTask = weakTask, let strongSelf = self else { return }
            strongTask.handleResponse(data: resp.value, error: resp.error,
                                      response: resp.response, filePath: resp.fileURL?.path)
            strongSelf.taskList.removeFirst(where: { $0 == strongTask })
        }
        
        taskList.append(task)
        return task
    }
    
    private func downloadFiles(_ urls: [String], _ block: @escaping ([String: String]) -> Void) {
        let urlSet: [String] = Array(Set(urls))
        
        let opQueue = OperationQueue()
        let semaphore = DispatchSemaphore(value: 0)
        
        var resultDict: [String: String] = [:]
        for url in urlSet {
            opQueue.addOperation {
                AF.download(url).responseData { resp in
                    if resp.error == nil, let filePath = resp.fileURL?.path {
                        resultDict[url] = filePath
                    }
                    semaphore.signal()
                }
                semaphore.wait()
            }
        }
        opQueue.waitUntilAllOperationsAreFinished()
        DispatchQueue.main.async {
            block(resultDict)
        }
    }
    
    private func uploadFile(_ data: Data,
                            url: String,
                            headers: [String: String]? = nil) -> JHBaseNetworkRequest {
        let task = JHBaseNetworkRequest()
        
        var httpHeaders: HTTPHeaders? = nil
        if let headersDict = headers {
            httpHeaders = HTTPHeaders(headersDict)
        }
        
        weak var weakTask = task
        task.request = AF.upload(data, to: url, headers: httpHeaders).uploadProgress { progress in
            guard let strongTask = weakTask else { return }
            strongTask.handleProgress(progress: progress)
        }.validate().response { [weak self] resp in
            guard let strongTask = weakTask, let strongSelf = self else { return }
            strongTask.handleResponse(data: resp.data, error: resp.error, response: resp.response)
            strongSelf.taskList.removeFirst(where: { $0 == strongTask })
        }
        
        taskList.append(task)
        return task
    }
    
    // 读取 JHVersion.plist 中的配置
    private func readClientInfoDict() -> [String: Any] {
        let version = clientInfoDict["version"] as? String ?? "v1.8.0"
        let versionNum = clientInfoDict["versionNum"] as? Int ?? 180
        let device = clientInfoDict["device"] as? String ?? "ios"
        let appID = Bundle.main.infoDictionary?["APPID"] as? String ?? JHBaseInfo.appID
        let userID = JHBaseInfo.userID
        let clientDict: [String: Any] = ["version": version, "versionNum": versionNum,
                                         "device": device, "appid": appID, "userId": userID]
        return clientDict
    }
}

public class JHBaseNetworkRequest: Equatable {
    var request: Alamofire.Request?
    
    public typealias JHBaseResponseClosure = (_ : JHBaseNetworkResponse) -> Void
    public typealias JHBaseProgressClosure = (Progress) -> Void
    
    private var responseHandler: JHBaseResponseClosure?
    private var progressHandler: JHBaseProgressClosure?
    
    // MARK: - API
    @discardableResult
    public func response(_ closure: @escaping JHBaseResponseClosure) -> Self {
        responseHandler = closure
        return self
    }
    
    @discardableResult
    public func progress(closure: @escaping JHBaseProgressClosure) -> Self {
        progressHandler = closure
        return self
    }
    
    public func cancel() {
        request?.cancel()
    }
    
    // MARK: - Equatable
    public static func == (lhs: JHBaseNetworkRequest, rhs: JHBaseNetworkRequest) -> Bool {
        return lhs.request?.id == rhs.request?.id
    }
    
    // MARK: - Private
    fileprivate func handleResponse(data: Data? = nil,
                                    error: AFError? = nil,
                                    response: HTTPURLResponse? = nil,
                                    filePath: String? = nil) {
        if let responseHandler = responseHandler {
            let baseResp = convertResponse(data: data, error: error, response: response)
            baseResp.filePath = filePath
            responseHandler(baseResp)
        }
    }
    
    fileprivate func convertResponse(data: Data? = nil,
                                     error: AFError? = nil,
                                     response: HTTPURLResponse? = nil) -> JHBaseNetworkResponse {
        let code = response?.statusCode
        let headers = response?.allHeaderFields as? [String: String] ?? [:]
        
        var baseError: JHBaseNetworkError? = nil
        if let error = error, let errorCode = error.responseCode {
            baseError = JHBaseNetworkError(code: errorCode, desc: error.localizedDescription)
        }
        
        let baseResp = JHBaseNetworkResponse(data: data, error: baseError,
                                             statusCode: code, headers: headers)
        return baseResp
    }
    
    fileprivate func handleProgress(progress: Foundation.Progress) {
        if let closure = progressHandler {
            closure(progress)
        }
    }
}

public class JHBaseNetworkResponse {
    public let data: Data?
    public let error: JHBaseNetworkError?
    
    public let statusCode: Int?
    public let headers: [String: String]?
    
    public var filePath: String? = nil
    
    init(data: Data?, error: JHBaseNetworkError?,
         statusCode: Int?, headers: [String: String]?) {
        self.data = data
        self.error = error
        self.statusCode = statusCode
        self.headers = headers
    }
}

public class JHBaseNetworkError {
    public let errorCode: Int?
    public let errorDesc: String?
    
    init(code: Int?, desc: String?) {
        self.errorCode = code
        self.errorDesc = desc
    }
}
