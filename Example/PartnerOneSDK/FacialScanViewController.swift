import UIKit
import FaceTecSDK

final class FacialScanViewController: UIViewController, FaceTecFaceScanProcessorDelegate, URLSessionDelegate {
  
  //MARK: - Properties
  
  var viewModel: ScanViewModel
  
  private var latestExternalDatabaseRefID: String = ""
  private var latestSessionResult: FaceTecSessionResult!
  private var latestIDScanResult: FaceTecIDScanResult!
  private var latestProcessor: Processor!
  private var utils: SampleAppUtilities?
  
  //MARK: - init
  
  init(viewModel: ScanViewModel = ScanViewModel()) {
    self.viewModel = viewModel
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  //MARK: - View Lifecycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    view.backgroundColor = .white
    
    FaceTec.initialize()
    setupFaceTec()
  }
}

//MARK: - Private Functions

extension FacialScanViewController {
  func setupFaceTec() {
    FaceTec.sdk.initializeInDevelopmentMode(deviceKeyIdentifier: "",
                                            faceScanEncryptionKey: "")
    Config.initializeFaceTecSDKFromAutogeneratedConfig(completion: { initializationSuccessful in
      
    })
  }
  
  func processSessionWhileFaceTecSDKWaits(sessionResult: FaceTecSessionResult,
                                          faceScanResultCallback: FaceTecFaceScanResultCallback) {}
  
  func onFaceTecSDKCompletelyDone() {}
  
  func onComplete() {
    print("Escaneamento Completo. Navegando para Status!")
    viewModel.navigateStatusView()
  }
  
  func getLatestExternalDatabaseRefID() -> String {
      return latestExternalDatabaseRefID;
  }
  
  func setLatestSessionResult(sessionResult: FaceTecSessionResult) {
      latestSessionResult = sessionResult
  }
}
