


import UIKit
import CoreData
import MWFeedParser

class checkLink: NSObject, MWFeedParserDelegate {
    func feedParser(_ parser: MWFeedParser!, didParseFeedInfo info: MWFeedInfo!) {
    }
}

class MenuTableViewController: UITableViewController, MWFeedParserDelegate {

    let check = checkLink()
    var channels = [NSManagedObject]()
    let whitespaceSet = CharacterSet.whitespaces
    var feedInfo = [MWFeedInfo]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableFooterView = UIView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadSources()
    }
    
    //MARK: - FEED PARSER DELEGARE + METHODS
    
    func feedParserDidStart(_ parser: MWFeedParser!) {
    }
    
    func feedParserDidFinish(_ parser: MWFeedParser!) {
    }
    func feedParser(_ parser: MWFeedParser!, didParseFeedInfo info: MWFeedInfo!) {
        feedInfo.append(info)
        
    }
    func feedParser(_ parser: MWFeedParser!, didFailWithError error: Error!) {
        let code = (error as NSError).code
        if code == 2 {
            let alert = UIAlertController(title: "Error", message: "No network", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
            AIManager.aiManager.removeActivityIndicator()
            return
        }
    }

    func reloadSources() {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let managedContext = appDelegate.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Channel")
        do {
            let results = try managedContext.fetch(fetchRequest)
            channels = results as! [NSManagedObject]
            loadRSSList()
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
    }
    
    func request(_ rssString: String) {
        let url = URL(string: rssString)
        let feedParser = MWFeedParser(feedURL: url)
        feedParser?.delegate = self
        feedParser?.connectionType = ConnectionTypeSynchronously
        feedParser?.feedParseType = ParseTypeInfoOnly
        feedParser?.parse()
    }
    func loadRSSList() {
        feedInfo = [MWFeedInfo]()
        
        for item in channels {
            request(item.value(forKey: "channel") as! String)
        }
        self.tableView.reloadData()
        
    }

    @IBAction func addCategory(_ sender: AnyObject) {
        
        let alert = UIAlertController(title: "New Channel",
                                      message: "Add a new RSS",
                                      preferredStyle: .alert)
        
        let saveAction = UIAlertAction(title: "Save",
                                       style: .default,
                                       handler: { (action:UIAlertAction) -> Void in
                                        
                                        let textField = alert.textFields!.first
                                        
                                        guard let temp = textField?.text!, !temp.trimmingCharacters(in: self.whitespaceSet).isEmpty else {
                                            return
                                        }
                                        do {
                                            let feedParser = MWFeedParser(feedURL: URL(string: (textField?.text)!))
                                            feedParser?.connectionType = ConnectionTypeSynchronously
                                            feedParser?.delegate = self.check
                                            if feedParser?.parse() == false {
                                                let alert = UIAlertController(title: "Error", message: "Incorrect link type provided.", preferredStyle: UIAlertControllerStyle.alert)
                                                alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler: nil))
                                                self.present(alert, animated: true, completion: nil)
                                                return
                                            }
                                        }
                                        
                                        let appDelegate = UIApplication.shared.delegate as! AppDelegate
                                        let managedContext = appDelegate.persistentContainer.viewContext
                                        let entity =  NSEntityDescription.entity(forEntityName: "Channel", in:managedContext)
                                        let channel = NSManagedObject(entity: entity!, insertInto: managedContext)
                                        channel.setValue(textField?.text!, forKey: "channel")
                                        appDelegate.saveContext()
                                        self.reloadSources()
        })
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        alert.addTextField {
            (textField: UITextField) -> Void in
        }
        
        alert.addAction(saveAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true,
                     completion: nil)
    }


    // MARK: - TABLE VIEW DELEGATE

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 2 {
            return feedInfo.count
        }
        return 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "menuCell", for: indexPath)
        switch indexPath.section {
        case 0:
            cell.textLabel?.text = "All"
        case 1:
            cell.textLabel?.text = "Favorites"
        case 2:
            cell.textLabel?.text = feedInfo[indexPath.row].title
        default:
            break
        }
        
        return cell
    }
    
    //MARK: - TABLE VIEW DATA SOURCE
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let secondVC = (self.revealViewController().frontViewController as! CustomNavigationViewController).topViewController as! FrontViewController
        switch indexPath.section {
        case 0:
            secondVC.choosenChannel = "All"
        case 1:
            secondVC.choosenChannel = "Favorites"
        case 2:
            secondVC.choosenChannel = "\(indexPath.row)"
        default:
            break
        }
        self.revealViewController().revealToggle(self)
    }

 
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if indexPath.section == 2 {
            return true
        } else {
            return false
        }
    }
 
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if (editingStyle == .delete ) {

        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        
        let favoriteAction = UITableViewRowAction(style: .normal, title: channels[indexPath.row].value(forKey: "isFavorite") as! Bool ? "Unfavorite" : "Favorite") { (action, indexPath) in
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            let managedContext = appDelegate.persistentContainer.viewContext
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Channel")
            do {
                let results = try managedContext.fetch(fetchRequest)
                let channel = results[indexPath.row]
                let tempBool = self.channels[indexPath.row].value(forKey: "isFavorite") as! Bool ? false : true
                (channel as AnyObject).setValue(tempBool, forKey: "isFavorite")
                appDelegate.saveContext()
            } catch let error as NSError {
                print("Could not fetch \(error), \(error.userInfo)")
            }
            self.reloadSources()
        }
        
        let deleteAction = UITableViewRowAction(style: .default, title: "Delete") { (action, indexPath) in
            let secondVC = (self.revealViewController().frontViewController as! CustomNavigationViewController).topViewController as! FrontViewController
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            let managedContext = appDelegate.persistentContainer.viewContext
            managedContext.delete(self.channels[indexPath.row])
            appDelegate.saveContext()
            if secondVC.choosenChannel == "\(indexPath.row)" {
                secondVC.choosenChannel = "All"
            }
            self.reloadSources()
        }
        return [deleteAction, favoriteAction]
    }

    // MARK: - Navigation


}
