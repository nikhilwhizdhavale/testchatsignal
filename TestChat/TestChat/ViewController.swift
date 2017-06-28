//
//  ViewController.swift
//  TestChat
//
//  Created by Nikhil Modi on 6/26/17.
//  Copyright © 2017 Nikhil Modi. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    @IBAction func openChat(_ sender: Any) {
        let registrationController = RegistrationViewController()
        self.present(registrationController, animated: true, completion: nil)
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

