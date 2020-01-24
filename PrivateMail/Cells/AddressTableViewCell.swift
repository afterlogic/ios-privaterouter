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


struct AddressCellContent {
    var fullName: String?
    var email: String
    var enable: Bool = true
}


class AddressTableViewCell: UITableViewCell {
    
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var collectionView: UICollectionView!
    @IBOutlet var heightConstraint: NSLayoutConstraint!
    @IBOutlet var plusButton: UIButton!
    
    weak open var delegate: AddressTableViewCellDelegate?
    
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
            plusButton.isHidden = true
        }
    }
    
    var items: [AddressCellContent] = [] {
        didSet {
            collectionView.reloadData()
            collectionView.layoutIfNeeded()
            
            if collectionView.contentSize.height > 50 {
                heightConstraint.constant = min(collectionView.contentSize.height, 186)
            } else {
                heightConstraint.constant = 50.0
            }
            
            var emails: [String] = []
            
            for item in items {
                emails.append(item.email)
            }
            
            switch style {
            case .from:
                ComposeMailModelController.shared.mail.from = emails
                break
                
            case .to:
                ComposeMailModelController.shared.mail.to = emails
                break
                
            case .cc:
                ComposeMailModelController.shared.mail.cc = emails
                break
                
            case .bcc:
                ComposeMailModelController.shared.mail.bcc = emails
                break
            }
            
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.theme_backgroundColor = .surface
        titleLabel.theme_textColor = .onSurfaceMinorText
        plusButton.theme_tintColor = .accent
        
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(UINib(nibName: AddressCollectionViewCell.cellID(), bundle: Bundle.main), forCellWithReuseIdentifier: AddressCollectionViewCell.cellID())
        collectionView.register(UINib(nibName: AddressFieldCollectionViewCell.cellID(), bundle: Bundle.main), forCellWithReuseIdentifier: AddressFieldCollectionViewCell.cellID())
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
    }
    
    @IBAction func plusButtonAction(_ sender: Any) {
        if let vc = self.delegate as? UIViewController {
            vc.performSegue(withIdentifier: "AddContact", sender: self)
        }
    }
    
    func setItems(_ emails: [String],_ enable:Bool) {
        items = []
        
        for email in emails {
            let contacts = StorageProvider.shared.getContacts(nil, search: email)
            var fullName: String? = nil
            
            if contacts.count > 0 {
                fullName = contacts[0].fullName
            }
            
            let contact = AddressCellContent(fullName: fullName, email: email,enable: enable)
            items.append(contact)
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
        return items.count + 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.item < items.count {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: AddressCollectionViewCell.cellID(), for: indexPath) as! AddressCollectionViewCell
            
            cell.delegate = self
            cell.deleteButton.isHidden = !items[indexPath.item].enable
            if items[indexPath.item].fullName != nil {
                cell.titleLabel.text = items[indexPath.item].fullName
            } else {
                cell.titleLabel.text = items[indexPath.item].email
            }
            
            cell.email = items[indexPath.item].email
            cell.backView.layer.cornerRadius = cell.frame.size.height / 2.0
            
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: AddressFieldCollectionViewCell.cellID(), for: indexPath) as! AddressFieldCollectionViewCell
            cell.delegate = self
            
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let height = CGFloat(AddressCollectionViewCell.cellHeight)
        
        if indexPath.item < items.count {
            let font = UIFont.systemFont(ofSize: 14.0)
            
            let label = items[indexPath.row].fullName ?? items[indexPath.row].email
            var width = label.width(withConstrainedHeight: height, font: font)
            
            width += 16.0 + height
            
            if width > collectionView.frame.size.width {
                width = collectionView.frame.size.width
            }
            
            return CGSize(width: width, height: height)
        } else {
            return CGSize(width: collectionView.frame.width, height: height)
        }
    }
}


extension AddressTableViewCell: AddressCollectionViewCellProtocol {
    func deleteAddress(email: String) {
        if let index = items.firstIndex(where: { (item) -> Bool in
            return item.email == email
        }) {
            items.remove(at: index)
            delegate?.cellSizeDidChanged()
        }
    }
}

protocol AddressTableViewCellDelegate: UITableViewDelegateExtensionProtocol {
    
    func addressCellContentTriggered(_ cell: AddressTableViewCell)
    
}


extension AddressTableViewCell: AddressFieldCollectionViewCellProtocol {
    
    func addressTextFieldBeginEditing() {
        plusButton.isHidden = false
        delegate?.addressCellContentTriggered(self)
    }
    
    func addAddress(email: String?) {
        plusButton.isHidden = true
        delegate?.addressCellContentTriggered(self)
        
        if let email = email?.replacingOccurrences(of: " ", with: ""), email.count > 0 {
            if email.isEmail {
                let contacts = StorageProvider.shared.getContacts(nil, search: email)
                var fullName: String? = nil
                
                if contacts.count > 0 {
                    fullName = contacts[0].fullName
                }
                
                let contact = AddressCellContent(fullName: fullName, email: email)
                
                if !self.items.contains(where: { (item) -> Bool in
                    return item.email == contact.email && item.fullName == contact.fullName
                }) {
                    self.items.append(contact)
                    self.delegate?.cellSizeDidChanged()
                }
            } else {
                SVProgressHUD.showError(withStatus: NSLocalizedString("Invalid email", comment: ""))
            }
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
