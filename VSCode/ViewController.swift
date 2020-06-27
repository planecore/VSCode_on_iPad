//
//  ViewController.swift
//  VSCode
//
//  Created by Matan Mashraki on 30/06/2019.
//  Copyright © 2019 Matan Mashraki. All rights reserved.
//

import UIKit
import WebKit
import KeychainSwift

var mainVC: ViewController? = nil
class ViewController: UIViewController {
    
    @IBOutlet weak var webView: WKWebView!
    /// The activity indicator in the navigation bar
    private let activityIndicator = UIActivityIndicatorView(frame: CGRect(x: 0, y: 0, width: 20, height: 20))
    /// This view is used to set a color for the home indicator area on newer iPads, so it'll match VSCode's task bar color.
    private var insetView: UIView? = nil
    /// Keyboard height in order to adjust `webView` height
    private var keyboardHeight: CGFloat = 0 {
        didSet {
            guard let bottomSafeArea = view.window?.safeAreaInsets.bottom else {
                return
            }
            var offset = bottomSafeArea - keyboardHeight
            // there's a bug on the iPadOS beta where the system tells the app that the keyboard is up even
            // when it's not. this line should prevent that from happening.
            if offset == -420 {
                return
            }
            if offset > 0 {
                offset = 0
            }
            // updates the home indicator area color
            if offset == 0 {
                insetView = paintSafeAreaBottomInset(withColor: UIColor(rgbString: "rgb(0, 122, 204)")!)
            } else {
                removeSafeAreaBottomInsetColor(insetView: insetView)
            }
            view.constraintWithIdentifier("webViewBottom")?.constant = offset
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        webView.navigationDelegate = self
        // disables the bounce when user trys to scroll non-scrollable areas.
        webView.scrollView.bounces = false
        webView.scrollView.delegate = self
        // adding activity indicator to navigation bar
        let currentReload = navigationItem.rightBarButtonItem!
        let barButton = UIBarButtonItem(customView: activityIndicator)
        navigationItem.setRightBarButtonItems([currentReload, barButton], animated: false)
        setKeyboardNotifications()
    }
    
    /// Adds notifications to detect keyboard frame changes.
    func setKeyboardNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardStateChanges), name: UIResponder.keyboardDidChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardHides), name: UIResponder.keyboardDidHideNotification, object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        mainVC = self
        loadViewContent(stopWebView: false)
    }
    
    // WKWebView doesn't update the layout of code-server (probably a bug) when we change
    // its size, so we'll force code-server to relayout.
    override func viewDidLayoutSubviews() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.webView.evaluateJavaScript("var evt = document.createEvent('UIEvents'); evt.initUIEvent('resize', true, false,window,0); window.dispatchEvent(evt); ", completionHandler: nil)
        }
    }
    
    /**
     Loads the web view, if it's a new user it'll present `FormViewController`.
     
     - Parameter stopWebView: When the user deletes its code-server address use `stopWebView` to stop code-server web view.
    */
    func loadViewContent(stopWebView: Bool) {
        if UserDefaults.standard.contains(key: "host") {
            loadWebView()
        } else {
            if stopWebView {
                webView.load(URLRequest(url: URL(string:"about:blank")!))
                removeSafeAreaBottomInsetColor(insetView: insetView)
            } else {
                loadWelcome()
            }
        }
    }
    
    /// Load code-server with the address the user provided.
    func loadWebView() {
        guard let url = UserDefaults.standard.url(forKey: "host") else {
            return
        }
        let request = URLRequest(url: url)
        webView.load(request)
    }
    
    /// Shows `FormViewController` when opening the app and there's no code-server address provided.
    func loadWelcome() {
        performSegue(withIdentifier: "presentSettings", sender: self)
    }
    
    /// Refresh code-server web view when the reload button in the navigation bar is tapped.
    @IBAction func refreshWebView(_ sender: Any) {
        webView.reloadFromOrigin()
    }
    
    /// Called when keyboard frame changes
    @objc func keyboardStateChanges(_ notification: Notification) {
        if let keyboardFrame: NSValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
            let keyboardRectangle = keyboardFrame.cgRectValue
            if keyboardRectangle.height == 216 || keyboardRectangle.height == 244 {
                // when using the floating keyboard the webview should fill the whole screen.
                self.keyboardHeight = 0
            } else {
                self.keyboardHeight = keyboardRectangle.height
            }
        }
    }
    
    /// Called when keyboard hides
    @objc func keyboardHides(_ notification: Notification) {
        self.keyboardHeight = 0
    }
    
}

extension ViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        activityIndicator.startAnimating()
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        activityIndicator.stopAnimating()
        guard let url = webView.url else {
            return
        }
        if url.lastPathComponent == "login" {
            // the login page has a white background so we'll match the home indicator area to its color.
            insetView = paintSafeAreaBottomInset(withColor: UIColor.white)
            // if the user provided its password, we'll auto-fill his password automatically.
            if var password = KeychainSwift().get("password") {
                password = password.replacingOccurrences(of: #"\"#, with: #"\\"#)
                password = password.replacingOccurrences(of: #"'"#, with: #"\'"#)
                password = password.replacingOccurrences(of: #"\""#, with: #"\\""#)
                webView.evaluateJavaScript(#"var myInterval = window.setInterval(() => { if (document.querySelector('input[type="password"]') !== undefined) { document.querySelector('input[type="password"]').value = ""# + password + #""; document.querySelector('input[type="submit"]').click(); clearInterval(myInterval); } }, 100)"#, completionHandler: nil)
            }
        } else if url.absoluteString != "about:blank" {
            // code-server loaded, match its color to VSCode's tab bar.
            insetView = paintSafeAreaBottomInset(withColor: UIColor(rgbString: "rgb(0, 122, 204)")!)
        }
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        activityIndicator.stopAnimating()
    }
}

extension ViewController: UIScrollViewDelegate {
    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        scrollView.pinchGestureRecognizer?.isEnabled = false
    }
}

extension UserDefaults {
    /**
     Check if `UserDefaults` contains value for key.
     
     - Parameter key: The key to search value for.
     
     - Returns: Is there a value for the key.
    */
    func contains(key: String) -> Bool {
        return self.object(forKey: key) != nil
    }
}

/// Few functions to set and remove the colors of the home indicator area.
extension UIViewController {
    // https://stackoverflow.com/a/47353886
    private static let insetBackgroundViewTag = 98721
    func paintSafeAreaBottomInset(withColor color: UIColor) -> UIView? {
        guard #available(iOS 11.0, *) else {
            return nil
        }
        if let insetView = view.viewWithTag(UIViewController.insetBackgroundViewTag) {
            insetView.backgroundColor = color
            return nil
        }
        let insetView = UIView(frame: .zero)
        insetView.tag = UIViewController.insetBackgroundViewTag
        insetView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(insetView)
        view.sendSubviewToBack(insetView)
        insetView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        insetView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        insetView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        insetView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true
        insetView.backgroundColor = color
        return insetView
    }
    
    func removeSafeAreaBottomInsetColor(insetView: UIView? = nil) {
        guard #available(iOS 11.0, *) else {
            return
        }
        if let insetView = view.viewWithTag(UIViewController.insetBackgroundViewTag) {
            insetView.backgroundColor = nil
            return
        }
        insetView?.removeFromSuperview()
    }
}

extension UIColor {
    /**
     Initialize `UIColor` from JavaScript string.
     
     - Parameter rgbString: JavaScript color string.
     
    */
    convenience init?(rgbString: String) {
        var str = rgbString.dropFirst(4)
        str = str.dropLast()
        str = str.split(separator: " ").joined() + ""
        let array = str.split(separator: ",")
        if let r = Double(array[0]), r >= 0 && r <= 255,
            let g = Double(array[1]), g >= 0 && g <= 255,
            let b = Double(array[2]), b >= 0 && b <= 255 {
            self.init(red: CGFloat(r/255), green: CGFloat(g/255), blue: CGFloat(b/255), alpha: 1.0)
        } else {
            return nil
        }
    }
}

extension UIView {
    /// Returns the first constraint with the given identifier, if available.
    ///
    /// - Parameter identifier: The constraint identifier.
    func constraintWithIdentifier(_ identifier: String) -> NSLayoutConstraint? {
        return self.constraints.first { $0.identifier == identifier }
    }
}
