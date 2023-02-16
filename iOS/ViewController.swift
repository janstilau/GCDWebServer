import GCDWebServers
import UIKit

class ViewController: UIViewController {
  @IBOutlet var label: UILabel?
  var webServer: GCDWebUploader!
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
    webServer = GCDWebUploader(uploadDirectory: documentsPath)
    webServer.delegate = self
    webServer.allowHiddenItems = true
    if webServer.start() {
      label?.text = "GCDWebServer running locally on port \(webServer.port)"
    } else {
      label?.text = "GCDWebServer not running!"
    }
  }
  
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    
    webServer.stop()
    webServer = nil
  }
}

extension ViewController: GCDWebUploaderDelegate {
  func webUploader(_: GCDWebUploader, didUploadFileAtPath path: String) {
    print("[UPLOAD] \(path)")
  }
  
  func webUploader(_: GCDWebUploader, didDownloadFileAtPath path: String) {
    print("[DOWNLOAD] \(path)")
  }
  
  func webUploader(_: GCDWebUploader, didMoveItemFromPath fromPath: String, toPath: String) {
    print("[MOVE] \(fromPath) -> \(toPath)")
  }
  
  func webUploader(_: GCDWebUploader, didCreateDirectoryAtPath path: String) {
    print("[CREATE] \(path)")
  }
  
  func webUploader(_: GCDWebUploader, didDeleteItemAtPath path: String) {
    print("[DELETE] \(path)")
  }
}
