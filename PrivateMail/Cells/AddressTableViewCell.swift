//
//  AddressTableViewCell.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit
import SVProgressHUD

enum AddressTableViewCellStyle {
    case from
    case to
    case cc
    case bcc
}


class AddressTableViewCell: UITableViewCell {
    
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var collectionView: UICollectionView!
    @IBOutlet var heightConstraint: NSLayoutConstraint!
    
    weak open var delegate: UITableViewDelegateExtensionProtocol?
    
    var style: AddressTableViewCellStyle = .from {
        didSet {
            var name = ""
            
            switch style {
            case .from:
                name = NSLocalizedString("From:", comment: "")
                break
                
            case .to:
                name = NSLocalizedString("To:", comment: "")
                break
                
            case .cc:
                name = NSLocalizedString("CC:", comment: "")
                break
                
            case .bcc:
                name = NSLocalizedString("BCC:", comment: "")
                break
            }
            
            titleLabel.text = name
        }
    }
    
    @IBOutlet var selectionButton: UIButton!
    
    var items: [String] = [] {
        didSet {
            collectionView.reloadData()
            collectionView.layoutIfNeeded()
            
            if collectionView.contentSize.height > 50 {
                heightConstraint.constant = min(collectionView.contentSize.height, 186)
            } else {
                heightConstraint.constant = 50.0
            }
            
            selectionButton.isHidden = items.count > 0
            
            switch style {
            case .from:
                ComposeMailModelController.shared.mail.from = items
                break
                
            case .to:
                ComposeMailModelController.shared.mail.to = items
                break
                
            case .cc:
                ComposeMailModelController.shared.mail.cc = items
                break
                
            case .bcc:
                ComposeMailModelController.shared.mail.bcc = items
                break
            }
            
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(UINib(nibName: AddressCollectionViewCell.cellID(), bundle: Bundle.main), forCellWithReuseIdentifier: AddressCollectionViewCell.cellID())
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
    }
    
    @IBAction func plusButtonAction(_ sender: Any) {
        let alert = UIAlertController(title: NSLocalizedString("Add email", comment: ""), message: nil, preferredStyle: .alert)
        
        alert.addTextField { (textField) in
            textField.placeholder = NSLocalizedString("Enter email", comment: "")
            textField.keyboardType = .emailAddress
        }
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Ok", comment: ""), style: .default, handler: { [weak alert] (_) in
            let textField = alert?.textFields![0]
            
            if var email = textField?.text {
                email = email.replacingOccurrences(of: " ", with: "")
                
                let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
                let emailTest = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
                
                if email.count > 0 {
                    if emailTest.evaluate(with: email) {
                        if !self.items.contains(email) {
                            self.items.append(email)
                            self.delegate?.cellSizeDidChanged()
                        }
                    } else {
                        SVProgressHUD.showError(withStatus: NSLocalizedString("Invalid email", comment: ""))
                    }
                }
            }
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil))
        
        if let vc = delegate as? UIViewController {
            vc.present(alert, animated: true, completion: nil)
        }
    }
    
}


extension AddressTableViewCell: UITableViewCellExtensionProtocol {
    static func cellID() -> String {
        return "AddressTableViewCell"
    }
}


extension AddressTableViewCell: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: AddressCollectionViewCell.cellID(), for: indexPath) as! AddressCollectionViewCell
        
        cell.delegate = self
        cell.titleLabel.text = items[indexPath.item]
        cell.email = items[indexPath.item]
        cell.backView.layer.cornerRadius = cell.frame.size.height / 2.0
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let height = CGFloat(AddressCollectionViewCell.cellHeight)
        let font = UIFont.systemFont(ofSize: 14.0)
        
        var width = items[indexPath.row].width(withConstrainedHeight: height, font: font)
        
        width += 16.0 + height
        
        if width > collectionView.frame.size.width {
            width = collectionView.frame.size.width
        }
        
        return CGSize(width: width, height: height)
    }
}


extension AddressTableViewCell: AddressCollectionViewCellProtocol {
    func deleteAddress(email: String) {
        if let index = items.index(of: email) {
            items.remove(at: index)
            delegate?.cellSizeDidChanged()
        }
    }
}


class LeftAlignedCollectionViewFlowLayout: UICollectionViewFlowLayout {
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        let attributes = super.layoutAttributesForElements(in: rect)
        
        minimumLineSpacing = 4.0
        minimumInteritemSpacing = minimumLineSpacing
        
        sectionInset.top = CGFloat((50.0 - AddressCollectionViewCell.cellHeight) / 2.0)
        sectionInset.bottom = sectionInset.top
        
        var leftMargin = sectionInset.left
        var maxY: CGFloat = -1.0
        
        attributes?.forEach { layoutAttribute in
            if layoutAttribute.frame.origin.y >= maxY {
                leftMargin = sectionInset.left
            }
            
            layoutAttribute.frame.origin.x = leftMargin
            
            leftMargin += layoutAttribute.frame.width + minimumInteritemSpacing
            maxY = max(layoutAttribute.frame.maxY , maxY)
        }
        
        return attributes
    }
}
