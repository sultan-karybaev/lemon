//
//  m3u8Handler.swift
//  WindmillComic
//
//  Created by hippo_san on 08/06/2017.
//  Copyright © 2017 Ziyideas. All rights reserved.
//

import Foundation

protocol M3u8ParserDelegate: class {
  func parseM3u8Succeeded(by parser: M3u8Parser)
  func parseM3u8Failed(by parser: M3u8Parser)
}

open class M3u8Parser {
    weak var delegate: M3u8ParserDelegate?
    
    var m3u8Data: String = ""
    var tsSegmentArray = [M3u8TsSegmentModel]()
    var tsPlaylist = M3u8Playlist()
    var identifier = ""
    
    public var headerContent: [String] = []

    func parse(with url: String) {
        print("parse")
        guard let m3u8ParserDelegate = delegate else {
          print("M3u8ParserDelegate not set.")
          return
        }
        if !(url.hasPrefix("http://") || url.hasPrefix("https://")) {
          print("M3u8Parser Invalid URL.")
          m3u8ParserDelegate.parseM3u8Failed(by: self)
          return
        }
        guard let contentURL = URL(string: url) else {
            print("M3u8Parser Invalid URL.")
            m3u8ParserDelegate.parseM3u8Failed(by: self)
            return
        }
        DispatchQueue.global(qos: .background).async {
            do {
                let m3u8Content = try String(contentsOf: contentURL, encoding: .utf8)
                if m3u8Content == "" {
                    print("M3u8Parser Empty m3u8 content.")
                    m3u8ParserDelegate.parseM3u8Failed(by: self)
                    return
                } else if let m3u8ContentStream = m3u8Content.range(of: "#EXT-X-STREAM-INF:") {
                    print("M3u8Parser m3u8ContentStream")
                    let segmentsString = String(m3u8Content.suffix(from: m3u8ContentStream.lowerBound))
                    guard let m3u8FileName = segmentsString.split(separator: "\n").last else { return }
                    let m3u8Bool = m3u8FileName.hasSuffix("m3u8")
                    if m3u8Bool {
                        guard let count = url.split(separator: "/").last?.count else { return }
                        var urlCopy = url
                        for _ in 1...count {
                            urlCopy.removeLast()
                        }
                        let newUrl = "\(urlCopy)\(m3u8FileName)"
                        print("M3u8Parser newUrl \(newUrl)")
                        self.parse(with: newUrl)
                    } else {
                        print("M3u8Parser there is no m3u8 file")
                        return
                    }
                } else {
                    guard (m3u8Content.range(of: "#EXTINF:") != nil) else {
                        print("M3u8Parser No EXTINF info.")
                        m3u8ParserDelegate.parseM3u8Failed(by: self)
                        return
                    }
                    self.m3u8Data = m3u8Content
                    if self.tsSegmentArray.count > 0 { self.tsSegmentArray.removeAll() }
                    let segmentRange = m3u8Content.range(of: "#EXTINF:")!
                    //print("M3u8Parser m3u8Content \(m3u8Content)")
                    let m3u8Splited = m3u8Content.split(separator: "\n")
                    //print("M3u8Parser m3u8Splited \(m3u8Splited)")
                    var m3u8SegmentArray: [String] = []
                    var isHeaderFinished = false
                    m3u8Splited.forEach({ (substring) in
                        if !substring.contains("#EXTINF:") && !isHeaderFinished {
                            self.headerContent.append(String(substring))
                        } else {
                            isHeaderFinished = true
                            m3u8SegmentArray.append(String(substring))
                        }
                    })
                    print("M3u8Parser self.headerContent \(self.headerContent)")
                    //print("M3u8Parser m3u8SegmentArray \(m3u8SegmentArray)")
                    let segmentsString = String(m3u8Content.suffix(from: segmentRange.lowerBound)).components(separatedBy: "#EXT-X-ENDLIST")
                    //print("M3u8Parser segmentsString \(segmentsString)")
                    var segmentArray = segmentsString[0].components(separatedBy: "\n")
                    //print("M3u8Parser segmentArray \(segmentArray)")
                    segmentArray = segmentArray.filter { !$0.contains("#EXT-X-DISCONTINUITY") }
                    print("M3u8Parser segmentArray \(segmentArray)")
                    while (segmentArray.count > 2) {
                        if segmentArray[0] == "" || segmentArray[1] == "" { break }
                        var segmentModel = M3u8TsSegmentModel()
//                        let segmentDurationPart = segmentArray[0].components(separatedBy: ":")[1]
//                        var segmentDuration: Float = 0.0
//                        if segmentDurationPart.contains(",") {
//                            segmentDuration = Float(segmentDurationPart.components(separatedBy: ",")[0])!
//                        } else {
//                            segmentDuration = Float(segmentDurationPart)!
//                        }
                        
                        //print("segmentURL \(segmentURL)")
                        //segmentModel.duration = segmentDuration
                        segmentModel.duration = segmentArray[0]
                        let segmentURL = segmentArray[1]
                        segmentModel.locationURL = "\(contentURL.deletingLastPathComponent().absoluteString)\(segmentURL)"
                        self.tsSegmentArray.append(segmentModel)
                        segmentArray.remove(at: 0)
                        segmentArray.remove(at: 0)
                    }
                    self.tsPlaylist.initSegment(with: self.tsSegmentArray)
                    self.tsPlaylist.identifier = self.identifier
                    print("M3u8Parser return 111")
                    return print("M3u8Parser return 222")
                    print("M3u8Parser return 333")
                    m3u8ParserDelegate.parseM3u8Succeeded(by: self)
                }
            } catch let error {
                print(error.localizedDescription)
                print("Read m3u8 file content error.")
            }
        }
    }
}
