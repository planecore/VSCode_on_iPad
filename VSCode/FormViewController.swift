//
//  FormViewController.swift
//  VSCode
//
//  Created by Matan Mashraki on 30/06/2019.
//  Copyright © 2019 Matan Mashraki. All rights reserved.
//

import UIKit
import KeychainSwift

class FormViewController: UIViewController {
    
    @IBOutlet weak var addressTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var continueButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        continueButton.layer.cornerRadius = 10
        // fill current data in text fields if exists.
        if UserDefaults.standard.contains(key: "host") {
            addressTextField.text = UserDefaults.standard.url(forKey: "host")?.absoluteString
        }
        if let password = KeychainSwift().get("password") {
            passwordTextField.text = password
        }
    }
    
    /// Save the new data and reload the web view in `ViewController`.
    @IBAction func continueWithAddress(_ sender: Any) {
        if let address = URL(string: addressTextField.text ?? "no url") {
            UserDefaults.standard.set(address, forKey: "host")
        } else {
            UserDefaults.standard.removeObject(forKey: "host")
        }
        if let password = passwordTextField.text, !password.isEmpty {
            KeychainSwift().set(password, forKey: "password")
        } else {
            KeychainSwift().delete("password")
        }
        mainVC?.loadViewContent(stopWebView: true)
        self.dismiss(animated: true, completion: nil)
    }
    
    /// Show alert with explanation of why we need its password.
    @IBAction func tappedPasswordHelp(_ sender: Any) {
        let alert = UIAlertController(title: "Password AutoFill", message: "If you're using the default authentication method in code-server and you also set a password for it (meaning code-server doesn't generate a password everytime and prints it to the console), VSCode on iPad can enter the password automatically for you.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
}
