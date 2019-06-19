//
//  VideoDownloader.swift
//  WindmillComic
//
//  Created by Ziyi Zhang on 09/06/2017.
//  Copyright © 2017 Ziyideas. All rights reserved.
//

import Foundation

public enum Status {
  case started
  case paused
  case canceled
  case finished
}

protocol VideoDownloaderDelegate {
  func videoDownloadSucceeded(by downloader: VideoDownloader)
  func videoDownloadFailed(by downloader: VideoDownloader)
  
  func update(_ progress: Float)
}

open class VideoDownloader {
    public var downloadStatus: Status = .paused

    public var m3u8Data: String = ""
    var tsPlaylist = M3u8Playlist()
    public var headerContent: [String] = []
    
    private var segmentDownloaders = [SegmentDownloader]()
    private var tsFilesIndex = 0
    private var neededDownloadTsFilesCount = 0
    private var downloadURLs = [String]()
    private var downloadingProgress: Float {
        let finishedDownloadFilesCount = segmentDownloaders.filter({ $0.finishedDownload == true }).count
        let fraction = Float(finishedDownloadFilesCount) / Float(neededDownloadTsFilesCount)
        let roundedValue = round(fraction * 100) / 100
        print("downloadingProgress \(finishedDownloadFilesCount) \(fraction) \(roundedValue)")
        return roundedValue
    }
  
  
  fileprivate var startDownloadIndex = 2
  var delegate: VideoDownloaderDelegate?
  
  open func startDownload() {
    print("startDownload")
    if self.segmentDownloaders.count > 0 { self.segmentDownloaders.removeAll() }
    checkOrCreatedM3u8Directory()
    var newSegmentArray = [M3u8TsSegmentModel]()
    let notInDownloadList = tsPlaylist.tsSegmentArray.filter { !downloadURLs.contains($0.locationURL) }
    neededDownloadTsFilesCount = tsPlaylist.length
    print("neededDownloadTsFilesCount.count \(neededDownloadTsFilesCount) \(notInDownloadList.count) \(tsPlaylist.tsSegmentArray.count)")
    for i in 0 ..< notInDownloadList.count {
        let fileName = "\(tsFilesIndex).ts"
        let segmentDownloader = SegmentDownloader(with: notInDownloadList[i].locationURL, filePath: tsPlaylist.identifier, fileName: fileName, duration: notInDownloadList[i].duration, index: tsFilesIndex)
        segmentDownloader.delegate = self
        let filePath = getDocumentsDirectory().appendingPathComponent("Downloads").appendingPathComponent(tsPlaylist.identifier).appendingPathComponent(fileName).path
        print("finishedDownload \(tsPlaylist.identifier) \(FileManager.default.fileExists(atPath: filePath)) \(tsFilesIndex)")
        segmentDownloader.finishedDownload = FileManager.default.fileExists(atPath: filePath)
        segmentDownloaders.append(segmentDownloader)
        downloadURLs.append(notInDownloadList[i].locationURL)
        var segmentModel = M3u8TsSegmentModel()
        segmentModel.duration = segmentDownloaders[i].duration
        segmentModel.locationURL = segmentDownloaders[i].fileName
        segmentModel.index = segmentDownloaders[i].index
        newSegmentArray.append(segmentModel)
        tsFilesIndex += 1
    }
    tsPlaylist.tsSegmentArray = newSegmentArray
    print("notInDownloadList.count \(segmentDownloaders.count)")
    DispatchQueue.main.async {
        self.delegate?.update(self.downloadingProgress)
    }
    let finishedDownloadFilesCount = segmentDownloaders.filter({ $0.finishedDownload == true }).count
    if finishedDownloadFilesCount == neededDownloadTsFilesCount {
        delegate?.videoDownloadSucceeded(by: self)
        downloadURLs = []
        tsFilesIndex = 0
        downloadStatus = .finished
    }
    _ = segmentDownloaders.filter { (segmentDownloader) -> Bool in
        return !segmentDownloader.isDownloading && !segmentDownloader.finishedDownload
        }.map{ $0.startDownload() }
    //_ = segmentDownloaders.map { $0.startDownload() }
    //segmentDownloaders[0].startDownload()
    //segmentDownloaders[1].startDownload()
    //segmentDownloaders[2].startDownload()
    downloadStatus = .started
  }
  
  func checkDownloadQueue() {
    
  }
  
  func updateLocalM3U8file() {
    checkOrCreatedM3u8Directory()
    let filePath = getDocumentsDirectory().appendingPathComponent("Downloads").appendingPathComponent(tsPlaylist.identifier).appendingPathComponent("\(tsPlaylist.identifier).m3u8")
    //var header = "#EXTM3U\n#EXT-X-VERSION:3\n#EXT-X-TARGETDURATION:15\n"
    var header = self.headerContent.reduce("") { (result, line) -> String in
        return "\(result)\(line)\n"
    }
    var content = ""
    for i in 0 ..< tsPlaylist.tsSegmentArray.count {
      let segmentModel = tsPlaylist.tsSegmentArray[i]
      let length = "\(segmentModel.duration)\n"
      let fileName = "http://127.0.0.1:8080/\(segmentModel.index).ts\n"
      content += (length + fileName)
    }
    header.append(content)
    header.append("#EXT-X-ENDLIST\n")
    let writeData: Data = header.data(using: .utf8)!
    try! writeData.write(to: filePath)
  }
  
  private func checkOrCreatedM3u8Directory() {
    let filePath = getDocumentsDirectory().appendingPathComponent("Downloads").appendingPathComponent(tsPlaylist.identifier)
    if !FileManager.default.fileExists(atPath: filePath.path) {
      try! FileManager.default.createDirectory(at: filePath, withIntermediateDirectories: true, attributes: nil)
    }
  }
  
  open func deleteAllDownloadedContents() {
//    let filePath = getDocumentsDirectory().appendingPathComponent("Downloads").path
//    if FileManager.default.fileExists(atPath: filePath) {
//      try! FileManager.default.removeItem(atPath: filePath)
//    } else {
//      print("File has already been deleted.")
//    }
    let documentsUrl =  FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    do {
        let fileURLs = try FileManager.default.contentsOfDirectory(at: documentsUrl, includingPropertiesForKeys: nil, options: [])
        for fileURL in fileURLs {
            try FileManager.default.removeItem(at: fileURL)
        }
    } catch  { print(error) }
  }
  
  open func deleteDownloadedContents(with name: String) {
    let filePath = getDocumentsDirectory().appendingPathComponent("Downloads").appendingPathComponent(name).path
    if FileManager.default.fileExists(atPath: filePath) {
      try! FileManager.default.removeItem(atPath: filePath)
    } else {
      print("Could not find directory with name: \(name)")
    }
  }
  
  open func pauseDownloadSegment() {
    print("pauseDownloadSegment")
//    _ = segmentDownloaders.map { $0.pauseDownload() }
//    downloadStatus = .paused
    _ = segmentDownloaders.map { $0.cancelDownload() }
    downloadStatus = .canceled
  }
  
  open func cancelDownloadSegment() {
    print("cancelDownloadSegment")
    _ = segmentDownloaders.map { $0.cancelDownload() }
    downloadStatus = .canceled
  }
  
  open func resumeDownloadSegment() {
    print("resumeDownloadSegment \(segmentDownloaders.count)")
    _ = segmentDownloaders.filter { (segmentDownloader) -> Bool in
        return !segmentDownloader.isDownloading && !segmentDownloader.finishedDownload
    }.map{ $0.startDownload() }
    //_ = segmentDownloaders.map { $0.startDownload() }
    //_ = segmentDownloaders.map { $0.resumeDownload() }
    downloadStatus = .started
  }
}

extension VideoDownloader: SegmentDownloaderDelegate {
    
  func segmentDownloadSucceeded(with downloader: SegmentDownloader) {
    let finishedDownloadFilesCount = segmentDownloaders.filter({ $0.finishedDownload == true }).count
    DispatchQueue.main.async {
      self.delegate?.update(self.downloadingProgress)
    }
    updateLocalM3U8file()
    let downloadingFilesCount = segmentDownloaders.filter({ $0.isDownloading == true }).count
    print("segmentDownloadSucceeded downloadingFilesCount \(downloadingFilesCount) \(finishedDownloadFilesCount)")
    if finishedDownloadFilesCount == neededDownloadTsFilesCount {
      delegate?.videoDownloadSucceeded(by: self)
        downloadURLs = []
        tsFilesIndex = 0
      downloadStatus = .finished
    } else if startDownloadIndex == neededDownloadTsFilesCount - 1 {
      if segmentDownloaders[startDownloadIndex].isDownloading == true { return }
    }
//    else if downloadingFilesCount < 3 || finishedDownloadFilesCount != neededDownloadTsFilesCount {
//      if startDownloadIndex < neededDownloadTsFilesCount - 1 {
//        startDownloadIndex += 1
//      }
//      segmentDownloaders[startDownloadIndex].startDownload()
//    }
  }
  
  func segmentDownloadFailed(with downloader: SegmentDownloader) {
    delegate?.videoDownloadFailed(by: self)
  }
}
