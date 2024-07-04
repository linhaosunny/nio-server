//
//  LocalHttpServer+Cert.swift
//  NIOServer
//
//  Created by lishaxin on 2024/6/17.
//  Cert

import UIKit

/// p12 cert
enum SSLPKCS12Certificate: String {
    case server

    struct CertificateFile {
        /// ceritificate name
        let name: String
        
        /// Ceritificate passphrase
        let passphrase: String
    }
    
    struct CertificateData {
        /// ceritificate datas
        let bytes: [UInt8]
        
        /// Ceritificate passphrase
        let passphrase: String
    }

    struct Certificate {

        /// cert file
        var file: CertificateFile?
        ///  cert data
        var data: CertificateData?
    }

    /// file of cert's info
    fileprivate var file: CertificateFile {
        switch self {
        case .server:
            return .init(name: "server_certificate", passphrase: "nioserver_pass")
        }
    }
    
    /// data of cert's info
    fileprivate var data: CertificateData {
        switch self {
        case .server:
            return .init(bytes: certificate_bytes(), passphrase: certificate_passphrase() ?? "")
        }
    }

}

extension SSLPKCS12Certificate.CertificateFile {
    /// path
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
    
    /// file
    /// - Parameter certificate: cert
    /// - Returns: file of cert
    static func file(_ certificate: SSLPKCS12Certificate) -> CertificateFile {
        return certificate.file
    }
    
    /// data
    /// - Parameter certificate: cert
    /// - Returns: data of cert
    static func data(_ certificate: SSLPKCS12Certificate) -> CertificateData {
        return certificate.data
    }
}

/// MARK:  encrypt
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
    
    /// passphrase's encrypt
    /// - Returns: result
    fileprivate func passphrase_encrypt_enn() -> SSLPKCS12Certificate.CertificateEncrypt {
        switch self {
        case .server:
            return .data(head: "", tail: "")
        }
        
    }
    
    /// cert's encrypt
    /// - Returns: result
    fileprivate func certificate_encrypt_enn() -> SSLPKCS12Certificate.CertificateEncrypt {
        switch self {
        case .server:
            return .data(head: "", tail: "")
        }
    }
    
    
    /// origin passphrase
    /// - Returns: result
    fileprivate func certificate_passphrase() -> String? {
        switch self {
        case .server:
            let encrypt_text = passphrase_encrypt_enn().encrypt
            
            guard let decrypt = decrypt_content(decrypt: encrypt_text) else {
                return nil
            }
            return decrypt
        }
    }
    
    
    /// origin cert
    /// - Returns: result
    fileprivate func certificate_bytes() -> [UInt8] {
        switch self {
        case .server:
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

// MARK: encrypt
extension SSLPKCS12Certificate {
    /// enn encrypt
    /// - Parameter t: input
    /// - Returns: result
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
    
    /// dnn decrypt
    /// - Parameter t: input
    /// - Returns: result
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
    
    /// enn cert
    static func enn_cert_content() {
        guard let path = SSLPKCS12Certificate.file(.server).path,
              let data = try? Data(contentsOf: .init(fileURLWithPath: path))
        else { return  }
        
        let content = data.base64EncodedString()
        
        
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
    
    
    /// enn cert passphrase
    fileprivate static func enn_cert_passphrase() {
        let encrypt_text = "nioserver_pass"
        
        
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
