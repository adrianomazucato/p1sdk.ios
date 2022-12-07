import UIKit
import Alamofire
import ObjectMapper

protocol PartnerOneWorkerProtocol: AnyObject {
  func parseMainData(_ completion: @escaping (_ response: Response<TestModel>) -> Void)
  func postCPF(cpf: String, completion: @escaping (Response<AuthenticationModel>) -> Void)
}

class PartnerOneWorker: Request, PartnerOneWorkerProtocol {
  
  let network = DataParser()
  let apiURL = "https://integracao-sodexo-homologacao.partner1.com.br/swagger/v1/swagger.json/"
  
  func parseMainData(_ completion: @escaping (Response<TestModel>) -> Void) {
    guard let url = URL(string: "\(apiURL)") else {
      return
    }
    
    let params: Parameters = [
      "username": "HMG.IOS",
      "password": "eQtlC7BM",
      "grant_type": "password"
    ]
    
    network.mapperParser(url: url, method: .get, parameters: params, completion: completion)
  }
  
  func postCPF(cpf: String, completion: @escaping (Response<AuthenticationModel>) -> Void) {
    guard let url = URL(string: "\(apiURL)/api/authentication") else {
      return
    }
    
    let params: Parameters = [
      "cpf": cpf
    ]
    
    network.mapperParser(url: url, method: .post, parameters: params, completion: completion)
  }
}
