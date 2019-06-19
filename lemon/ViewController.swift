//
//  ViewController.swift
//  Demo
//
//  Created by Ziyi Zhang on 23/06/2017.
//  Copyright © 2017 hippo_san. All rights reserved.
//

import UIKit
import AVFoundation
import AVKit
//import AppFolder

//import Telegraph
//import Embassy

//import LemonDeer
import GCDWebServer

class ViewController: UIViewController {
  @IBOutlet var progressLabel: UILabel!
  @IBOutlet var downloadButton: UIButton!
  @IBOutlet var playerView: UIView!
  
  fileprivate var isDownloading = false
  fileprivate var duringDownloadingProcess = false
  
  private let lemonDeer = LemonDeer()
  private var server: GCDWebServer! = nil
  private var player = AVPlayer()
  private var playerLayer = AVPlayerLayer()
  
  @IBAction func download(_ sender: Any) {    
    print("download")
    if !isDownloading {
      DispatchQueue.main.async {
        self.downloadButton.setTitle("Pause", for: .normal)
      }
      isDownloading = true
      if duringDownloadingProcess {
        lemonDeer.downloader.resumeDownloadSegment()
      } else {
        let url = "http://www.oiboi.tv/vod/stream/trailer/4/master.m3u8"
        lemonDeer.directoryName = "Demo"
        lemonDeer.m3u8URL = url
        lemonDeer.delegate = self
        lemonDeer.parse()
//        print("download 222")
//        let path = getDocumentsDirectory().appendingPathComponent("Downloads").appendingPathComponent("Demo").path
//        if !FileManager.default.fileExists(atPath: path) {
//            print("download 333")
//
//        } else {
//            DispatchQueue.main.async {
//                self.downloadButton.setTitle("Download", for: .normal)
//            }
//            isDownloading = false
//        }
      }
    } else {
      DispatchQueue.main.async {
        self.downloadButton.setTitle("Download", for: .normal)
      }
      isDownloading = false
      duringDownloadingProcess = true
      lemonDeer.downloader.pauseDownloadSegment()
    }
  }
    
  @IBAction func playOnlineVideo(_ sender: Any) {
    print("playOnlineVideo")
    //configurePlayer(with: "http://185.38.12.38/sec/1556383687/313133369f64c3839bda356b4bbacb0a34c7a9f7b5bc07f6/ivs/81/19/e31587a03670/hls/tracks-3,4/index.m3u8")
    
    print("Bundle.main.bundleURL \(Bundle.main.path(forResource: "LemonDeer", ofType: "swift"))")
    print("Bundle.main.bundleURL \(Bundle.main.bundleURL)")
    
    var folderSize = 0
    func checkDirectory(directoryUrl: URL) {
        do {
            guard let isDirectory = try directoryUrl.resourceValues(forKeys: [.isDirectoryKey]).isDirectory else { print("isDirectory error"); return }
            if isDirectory {
                do {
                    //let urlArray = try FileManager.default.contentsOfDirectory(at: directoryUrl, includingPropertiesForKeys: nil)
                    let urlArray = try FileManager.default.contentsOfDirectory(at: directoryUrl, includingPropertiesForKeys: nil, options: [])
                    print("urlArray \(urlArray.count)")
                    //do {
                        try urlArray.lazy.forEach({ (url) in
                            checkDirectory(directoryUrl: url)
                            //guard let folderSize = try url.resourceValues(forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize else { return }
                        })
//                    } catch {
//
//                    }
                } catch {
                    
                }
            } else {
                print("directoryUrl \(directoryUrl)")
                guard let size = try directoryUrl.resourceValues(forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize else { return }
                folderSize += size
            }
        } catch {
            
        }
    }
    //let documentsDirectoryURL =  FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("Downloads").appendingPathComponent("Demo")
    let documentsDirectoryURL =  FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let template = URL(fileURLWithPath: NSTemporaryDirectory())
    checkDirectory(directoryUrl: template)
    let documentsDirectoryURLSize = folderSize
    checkDirectory(directoryUrl: documentsDirectoryURL)
    let documentsDirectoryURLSize2 = folderSize - documentsDirectoryURLSize
    let  byteCountFormatter =  ByteCountFormatter()
    byteCountFormatter.allowedUnits = .useBytes
    byteCountFormatter.countStyle = .file
    let folderSizeToDisplay = byteCountFormatter.string(for: folderSize) ?? ""
    let folderSizeToDisplay2 = byteCountFormatter.string(for: documentsDirectoryURLSize) ?? ""
    let folderSizeToDisplay3 = byteCountFormatter.string(for: documentsDirectoryURLSize2) ?? ""
    print("folderSizeToDisplay \(folderSizeToDisplay)")  // "X,XXX,XXX bytes"
    let alert = UIAlertController(title: "Size", message: "folderSizeToDisplay \(folderSizeToDisplay2)\n\n \(folderSizeToDisplay3)\n\n \(folderSizeToDisplay)",         preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
    self.present(alert, animated: true, completion: nil)
  }
  
  @IBAction func playLocalVideo(_ sender: Any) {
    print("playLocalVideo")
    server = GCDWebDAVServer(uploadDirectory: getDocumentsDirectory().appendingPathComponent("Downloads").appendingPathComponent("Demo").path)
    //server.start()
    server.delegate = self
    server.start(withPort: 8080, bonjourName: "GCD Web Server")
    let g = getDocumentsDirectory().appendingPathComponent("Downloads").appendingPathComponent("Demo").path
    print("getDocumentsDirectory() \(g)")
    configurePlayer(with: "http://127.0.0.1:8080/Demo.m3u8")
  }
  
  @IBAction func deleteDownloadedContents(_ sender: Any) {
    lemonDeer.downloader.deleteAllDownloadedContents()
    isDownloading = false
    duringDownloadingProcess = false
    //???
    progressLabel.text = "0 %"
  }
  
  @IBAction func deleteContentWithName(_ sender: Any) {
    let alert = UIAlertController(title: "Delete Content", message: "Input the name of directory you want to delete.", preferredStyle: .alert)
    alert.addTextField()
    let confirmAction = UIAlertAction(title: "OK", style: .default) { [weak alert] _ in
      self.lemonDeer.downloader.deleteDownloadedContents(with: (alert?.textFields?[0].text)!)
      self.progressLabel.text = " "
    }
    let cancelAction = UIAlertAction(title: "Cancel", style: .default) { [weak alert] _ in
      alert?.dismiss(animated: true)
    }
    alert.addAction(confirmAction)
    alert.addAction(cancelAction)
    present(alert, animated: true)
  }
  
  private func configurePlayer(with url: String) {
    print("configurePlayer")
    player.pause()
    playerLayer.removeFromSuperlayer()
    //player = AVPlayer(url: URL(fileURLWithPath: url))
    player = AVPlayer(url: URL(string: url)!)
//    playerLayer = AVPlayerLayer(player: player)
//    playerLayer.frame = CGRect(x: 0, y: 0, width: playerView.bounds.width, height: playerView.bounds.height)
//    playerView.layer.addSublayer(playerLayer)
//    player.play()
    performSegue(withIdentifier: "segueAVPlayer", sender: self)
  }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let player = segue.destination as? AVPlayerViewController {
            player.player = self.player
            player.player?.play()
        }
    }
    
}

extension ViewController: LemonDeerDelegate {
  func videoDownloadSucceeded() {
    print("Video download succeeded.")
    isDownloading = false
    duringDownloadingProcess = false
    DispatchQueue.main.async {
        //self.downloadButton.isUserInteractionEnabled = false
        self.downloadButton.setTitle("Download", for: .normal)
    }
  }
  
  func videoDownloadFailed() {
    print("Video download failed.")
    let template = URL(fileURLWithPath: NSTemporaryDirectory())
    do {
        let fileURLs = try FileManager.default.contentsOfDirectory(at: template, includingPropertiesForKeys: nil, options: [])
        for fileURL in fileURLs {
            try FileManager.default.removeItem(at: fileURL)
        }
    } catch  { print(error) }
  }
  
  func update(_ progress: Float, with directoryName: String) {
    progressLabel.text = "\(progress * 100) %"
  }
}

extension ViewController: GCDWebServerDelegate {
    func webServerDidCompleteBonjourRegistration(_ server: GCDWebServer) {
        print("webServerDidCompleteBonjourRegistration")
        if(server.serverURL == nil){
            let serverURL = server.bonjourServerURL
            //print("serverURL \(serverURL)")
            guard let url = serverURL?.absoluteString else { return }
            //print("url \(url)")
            //configurePlayer(with: "\(url)Demo.m3u8")
            //configurePlayer(with: "http://127.0.0.1:8080/Demo.m3u8")
            //configurePlayer(with: "http://0.0.0.0:8080/Demo.m3u8")
            //self.initWebView()
            //server.init
        } else {
            print("self.serverURL \(server.serverURL)")
            guard let url = server.serverURL?.absoluteString else { return }
            print("url \(url)")
            //configurePlayer(with: "\(url)Demo.m3u8")
        }
        
    }
    
    func webServerDidStart(_ server: GCDWebServer) {
        print("webServerDidStart \(server.serverURL)")
    }
    
    func webServerDidConnect(_ server: GCDWebServer) {
        print("webServerDidConnect \(server.serverURL)")
        //configurePlayer(with: "http://127.0.0.1:8080/Demo.m3u8")
    }
    
    func webServerDidUpdateNATPortMapping(_ server: GCDWebServer) {
        print("webServerDidUpdateNATPortMapping \(server.serverURL)")
    }
    
    
}

//extension ViewController: ServerDelegate {
//    func serverDidStop(_ server: Server, error: Error?) {
//        print("serverDidStop")
//    }
//}
