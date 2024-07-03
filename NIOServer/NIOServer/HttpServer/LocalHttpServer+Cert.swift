//
//  LocalHttpServer+Cert.swift
//  NIOServer
//
//  Created by lishaxin on 2024/6/17.
//  Cert

import UIKit

/// p12证书信息
enum SSLPKCS12Certificate: String {
    case vibemate

    struct CertificateFile {
        /// ceritificate name 证书名称
        let name: String
        
        /// Ceritificate passphrase
        let passphrase: String
    }
    
    struct CertificateData {
        /// ceritificate name 证书数据
        let bytes: [UInt8]
        
        /// Ceritificate passphrase
        let passphrase: String
    }

    struct Certificate {

        
        /// 文件路径形式
        var file: CertificateFile?
        ///  文件数据形式
        var data: CertificateData?
    }

    /// 证书信息
    fileprivate var file: CertificateFile {
        switch self {
        case .vibemate:
            return .init(name: "", passphrase: certificate_passphrase() ?? "")
        }
    }
    
    fileprivate var data: CertificateData {
        switch self {
        case .vibemate:
            return .init(bytes: certificate_bytes(), passphrase: certificate_passphrase() ?? "")
        }
    }

}

extension SSLPKCS12Certificate.CertificateFile {
    /// 证书文件路径
    var path: String? {
        func getFileBundle(name: String, path: FilePath)  -> String? {
            guard let path = path.filePath(name: name, type: .p12) else {
                return nil
            }
            
            return path
        }
        
        return getFileBundle(name: self.name, path: .mainBundle)
    }
}

extension SSLPKCS12Certificate {
    
    /// 使用文件
    /// - Parameter certificate: 证书
    /// - Returns: 文件
    static func file(_ certificate: SSLPKCS12Certificate) -> CertificateFile {
        return certificate.file
    }
    
    /// 使用证书数据
    /// - Parameter certificate: 证书
    /// - Returns: 数据
    static func data(_ certificate: SSLPKCS12Certificate) -> CertificateData {
        return certificate.data
    }
}

/// MARK: 加密相关
extension SSLPKCS12Certificate {
    enum CertificateEncrypt {
        case data(head: String, tail: String)
        
        var encrypt: String {
            switch self {
            case .data(let head, let tail):
                return SSLPKCS12Certificate.dnn(t: head) + tail
            }
        }
    }
    
    /// 加密后的密码
    /// - Returns: 结果
    fileprivate func passphrase_encrypt_enn() -> SSLPKCS12Certificate.CertificateEncrypt {
        switch self {
        case .vibemate:
            return .data(head: "", tail: "")
        }
        
    }
    
    /// 加密后的证书
    /// - Returns: 结果
    fileprivate func certificate_encrypt_enn() -> SSLPKCS12Certificate.CertificateEncrypt {
        switch self {
        case .vibemate:
            return .data(head: "", tail: "")
        }
    }
    
    
    /// 证书密码
    /// - Returns: 结果
    fileprivate func certificate_passphrase() -> String? {
        switch self {
        case .vibemate:
            let encrypt_text = passphrase_encrypt_enn().encrypt
            
            guard let decrypt = decrypt_content(decrypt: encrypt_text) else {
                return nil
            }
            return decrypt
        }
    }
    
    
    /// 证书内容
    /// - Returns: 结果
    fileprivate func certificate_bytes() -> [UInt8] {
        switch self {
        case .vibemate:
            let encrypt_text = certificate_encrypt_enn().encrypt
            
            
            guard let decrypt = decrypt_content(decrypt: encrypt_text) else {
                return []
            }
            
            guard let data = Data.init(base64Encoded: decrypt) else {
                return []
            }
            
            let bytes: [UInt8] = data.withUnsafeBytes {
                Array($0.bindMemory(to: UInt8.self))
            }
            return bytes
        }
    }
    
    fileprivate func decrypt_content(decrypt: String) -> String? {
        return decrypt
    }
}

// MARK: 加密撒盐操作
extension SSLPKCS12Certificate {
    /// 加密相关
    /// - Parameter t: 参数
    /// - Returns: 结果
    fileprivate static func enn(t: String) -> String {
        func reversed(text: String) -> String {
            return String(text.reversed())
        }

        
        func encrypt(text: String) -> String {
            return text.encrypt
        }
        
        
        func base64(text: String) -> String {
            // base64 encode
            return text.data(using: .utf8)!.base64EncodedString()
        }

        let r = reversed(text: t)
        let e = encrypt(text: r)
        let b = base64(text: e)
        return b
    }
    
    /// 解密相关
    /// - Parameter t: 参数
    /// - Returns: 结果
    fileprivate static func dnn(t: String) -> String {
        func reversed(text: String) -> String {
            return String(text.reversed())
        }
        
        func decrypt(text: String) -> String {
            // tokenDecrypt
            return text.decrypt!
        }
        
        func base64(text: String) -> String {
            // base64 decode
            return String(data: Data(base64Encoded: text)!, encoding: .utf8)!
        }

        let b = base64(text: t)
        let d = decrypt(text: b)
        let r = reversed(text: d)
        return r
    }
}

extension SSLPKCS12Certificate {
    
    /// 加密证书内容
    static func enn_cert_content() {
        guard let path = SSLPKCS12Certificate.file(.vibemate).path,
              let data = try? Data(contentsOf: .init(fileURLWithPath: path))
        else { return  }
        
        let content = data.base64EncodedString()
        
        // 加密内容
//        let encrypted = DXDtxUtils.dtxEncrypt(encrypt: content)
        
        let encrypted = content.encrypt
        
        let encryptText = encrypted.encrypt
        
        let head = String(encryptText.prefix(20))

        let head_enn = enn(t: head)
        
        let head_dnn = dnn(t: head_enn)
        // Get the remaining characters after the first 20
        let tail = String(encryptText.dropFirst(20))
    
        logger.debug(encryptText)
        
        enn_cert_passphrase()
    }
    
    
    /// 密钥加密
    fileprivate static func enn_cert_passphrase() {
        let encrypt_text = ""
        
        
        if let decrypt = encrypt_text.decrypt {
            let decryptedText = decrypt
            
            let head = String(encrypt_text.prefix(20))

            let head_enn = enn(t: head)
            
            let head_dnn = dnn(t: head_enn)
            // Get the remaining characters after the first 20
            let tail = String(encrypt_text.dropFirst(20))
            
            logger.debug(decryptedText)
        }
    }
}
