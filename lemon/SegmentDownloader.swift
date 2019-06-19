//
//  SegmentDownloader.swift
//  WindmillComic
//
//  Created by Ziyi Zhang on 09/06/2017.
//  Copyright © 2017 Ziyideas. All rights reserved.
//

import Foundation

protocol SegmentDownloaderDelegate {
  func segmentDownloadSucceeded(with downloader: SegmentDownloader)
  func segmentDownloadFailed(with downloader: SegmentDownloader)
}

class SegmentDownloader: NSObject {
  var fileName: String
  var filePath: String
  var downloadURL: String
    var duration: String
  //var duration: Float
  var index: Int
  
  lazy var downloadSession: URLSession = {
    let configuration = URLSessionConfiguration.default
    let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    
    //print("session.configuration.httpAdditionalHeaders \(session.configuration.connectionProxyDictionary)")
    return session
  }()
  
  var downloadTask: URLSessionDownloadTask?
  var isDownloading = false
  var finishedDownload = false
  
  var delegate: SegmentDownloaderDelegate?
  
  init(with url: String, filePath: String, fileName: String, duration: String, index: Int) {
    downloadURL = url
    self.filePath = filePath
    self.fileName = fileName
    self.duration = duration
    self.index = index
  }
  
  func startDownload() {
    print("SegmentDownloader startDownload \(downloadURL.suffix(6))")
    if checkIfIsDownloaded() {
      finishedDownload = true
      delegate?.segmentDownloadSucceeded(with: self)
    } else {
      let url = downloadURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
      //let u = "http://185.38.12.38/sec/1556383687/313133369f64c3839bda356b4bbacb0a34c7a9f7b5bc07f6/ivs/81/19/e31587a03670/hls/tracks-3,4/\(url)"
      guard let taskURL = URL(string: url) else { return }
        //print("downloadTask?.resume() \(taskURL) \(url) \(downloadURL) \(filePath)")
//        downloadTask = downloadSession.downloadTask(with: taskURL) { (URL2, URLResponse2, Error2) in
//            guard let resp = URLResponse2 else { return }
//            if let r = resp as? HTTPURLResponse {
//                //r.allHeaderFields
//                print("r.allHeaderFields \(r.allHeaderFields)")
//            }
//        }
        
        
//        downloadTask = URLSession.shared.downloadTask(with: taskURL) { (URL2, URLResponse2, Error2) in
//            guard let resp = URLResponse2 else { return }
//            if let r = resp as? HTTPURLResponse {
//                //r.allHeaderFields
//                print("r.allHeaderFields \(r.allHeaderFields)")
//            }
//        }
        
        downloadTask = downloadSession.downloadTask(with: taskURL)
        downloadTask?.resume()
        isDownloading = true
        
//        URLSession.shared.downloadTask(with: taskURL) { (URL2, URLResponse2, Error2) in
//            guard let resp = URLResponse2 else { return }
//            if let r = resp as? HTTPURLResponse {
//                r.allHeaderFields
//            }
//        }
    }
  }
  
  func cancelDownload() {
    downloadTask?.cancel()
    isDownloading = false
  }
  
  func pauseDownload() {
    if isDownloading {
        //downloadTask?.cancel()
        downloadTask?.suspend()
        isDownloading = false
    }
  }
  
  func resumeDownload() {
    downloadTask?.resume()
    isDownloading = true
  }
  
  func checkIfIsDownloaded() -> Bool {
    let filePath = generateFilePath().path
    if FileManager.default.fileExists(atPath: filePath) {
      return true
    } else {
      return false
    }
  }
  
  func generateFilePath() -> URL {
    return getDocumentsDirectory().appendingPathComponent("Downloads").appendingPathComponent(filePath).appendingPathComponent(fileName)
  }
}

extension SegmentDownloader: URLSessionDownloadDelegate {
  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    print("didFinishDownloadingTo \(downloadURL.suffix(6))")
    let destinationURL = generateFilePath()
    finishedDownload = true
    isDownloading = false
    if FileManager.default.fileExists(atPath: destinationURL.path) {
      return
    } else {
      do {
        try FileManager.default.moveItem(at: location, to: destinationURL)
        delegate?.segmentDownloadSucceeded(with: self)
      } catch let error as NSError {
        print(error.localizedDescription)
      }
    }
  }
  
  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    print("urlSession didCompleteWithError \(downloadURL.suffix(6)) \(error == nil)")
    //session.configuration
    if error != nil {
      finishedDownload = false
      isDownloading = false
      delegate?.segmentDownloadFailed(with: self)
    }
  }
    
    //urlSession
  
}
