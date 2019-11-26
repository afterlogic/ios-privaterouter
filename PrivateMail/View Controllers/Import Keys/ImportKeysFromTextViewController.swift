//
//  ImportKeysFromTextViewController.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit

class ImportKeysFromTextViewController: UIViewController {

    @IBOutlet var textView: UITextView!
    @IBOutlet var checkButton: UIButton!
    @IBOutlet var closeButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.theme_backgroundColor = .secondarySurface
        textView.theme_backgroundColor = .surface
        textView.theme_textColor = .onSurfaceMajorText

        title = NSLocalizedString("Import keys", comment: "")
        checkButton.setTitle(NSLocalizedString("CHECK KEYS", comment: ""), for: .normal)
        closeButton.setTitle(NSLocalizedString("CLOSE", comment: ""), for: .normal)
        
        checkButton.layer.cornerRadius = checkButton.bounds.height / 2.0
        closeButton.layer.cornerRadius = closeButton.bounds.height / 2.0
        textView.layer.cornerRadius = 10.0
        
        textView.doneAccessory = true
    }
    
    @IBAction func checkButtonAction(_ sender: Any) {
        performSegue(withIdentifier: "ImportListSegue", sender: nil)
    }
    
    @IBAction func closeButtonAction(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ImportListSegue" {
            let vc = segue.destination as! ImportKeysListViewController
            vc.keyString = textView.text
        }
    }
}
