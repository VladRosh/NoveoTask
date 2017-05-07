

import UIKit
import CoreData
import Alamofire
import AlamofireImage
import MWFeedParser
import DZNWebViewController

class FrontViewController: UIViewController, UISearchControllerDelegate, UISearchResultsUpdating, UISearchBarDelegate,  MWFeedParserDelegate, SWRevealViewControllerDelegate {
    
    @IBOutlet weak var noRSSView: UIView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var menuButton: UIBarButtonItem!
    let searchController = UISearchController(searchResultsController: nil)
    var channels = [NSManagedObject]()
    var choosenChannel: String!
    var feeditem = [MWFeedItem]()
    var feedInfo = MWFeedInfo()
    var parsedItems = [MWFeedItem]()
    
    struct oneChannel {
        var rssName : String!
        var rssFeeds : [MWFeedItem]
    }
    var allRSSArray = [oneChannel]()
    var filterdAllRssArray = [oneChannel]()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        choosenChannel = "All"
        tableView.tableFooterView = UIView()
        if self.revealViewController() != nil {
            self.revealViewController().delegate = self
            menuButton.target = self.revealViewController()
            menuButton.action = #selector(SWRevealViewController.revealToggle(_:))
            self.view.addGestureRecognizer(self.revealViewController().panGestureRecognizer())
            self.revealViewController().rearViewRevealOverdraw = 0
        }
        setUpSearchBar()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadChannels()
        //
    }
    
    //MARK: - Feed parser delegate
    
    func feedParserDidStart(_ parser: MWFeedParser!) {
        
    }
    
    func feedParserDidFinish(_ parser: MWFeedParser!) {
        allRSSArray.append(oneChannel(rssName: feedInfo.title, rssFeeds: parsedItems))
        parsedItems = [MWFeedItem]()
        if !channels.isEmpty {
            request()
        } else {
            AIManager.aiManager.removeActivityIndicator()
            self.tableView.reloadData()
        }
        
    }
    func feedParser(_ parser: MWFeedParser!, didParseFeedInfo info: MWFeedInfo!) {
        feedInfo = info
    }
    
    func feedParser(_ parser: MWFeedParser!, didParseFeedItem item: MWFeedItem!) {
        parsedItems.append(item)
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
        if !channels.isEmpty {
            request()
        } else {
            AIManager.aiManager.removeActivityIndicator()
            self.tableView.reloadData()
        }
    }

    func request() {
        let url = URL(string: channels.removeFirst().value(forKey: "channel") as! String)
        let feedParser = MWFeedParser(feedURL: url)
        feedParser?.delegate = self
        feedParser?.connectionType = ConnectionTypeAsynchronously
        feedParser?.parse()
    }
    
    func reloadChannels() {
        AIManager.aiManager.addActivityIndicator(self.view, style: nil, color: nil, backgroundColor: nil)
        allRSSArray = [oneChannel]()
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let managedContext = appDelegate.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Channel")
        do {
            let results = try managedContext.fetch(fetchRequest)
            if results.isEmpty {
                AIManager.aiManager.removeActivityIndicator()
                noRSSView.isHidden = false
                return
            } else {
                noRSSView.isHidden = true
            }
            switch choosenChannel {
            case "All":
                channels = results as! [NSManagedObject]
            case "Favorites":
                for result in results {
                    if (result as AnyObject).value(forKey: "isFavorite") as! Bool {
                        channels.append(result as! NSManagedObject)
                    }
                }
                if channels.isEmpty {
                    AIManager.aiManager.removeActivityIndicator()
                    noRSSView.isHidden = false
                }
            default:
                channels.append(results[Int(choosenChannel)!] as! NSManagedObject)
            }
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        if !channels.isEmpty {
            request()
        }
    }
    

    //MARK: - SEARCH CONTROLLER
    
    func setUpSearchBar() {
//        self.searchController = UISearchController(searchResultsController:  nil)
        self.searchController.searchResultsUpdater = self
        self.searchController.delegate = self
        self.searchController.searchBar.delegate = self
        self.searchController.hidesNavigationBarDuringPresentation = false
        self.searchController.dimsBackgroundDuringPresentation = false
        self.navigationItem.titleView = searchController.searchBar
        self.definesPresentationContext = true
        searchController.searchBar.barTintColor = UIColor(colorLiteralRed: (247.0/255.0), green: (247.0/255.0), blue: (247.0/255.0), alpha: 1)

    }
    func filterContentForSearchText(_ searchText: String, scope: String = "All") {
        filterdAllRssArray = [oneChannel]()
        for item in allRSSArray {
            var filteredParsedItems = [MWFeedItem]()
            for feed in item.rssFeeds {
                if feed.title.lowercased().contains(searchText.lowercased()) {
                    filteredParsedItems.append(feed)
                }
            }
            if !filteredParsedItems.isEmpty {
                filterdAllRssArray.append(oneChannel(rssName: item.rssName, rssFeeds: filteredParsedItems))
            }
        }
        tableView.reloadData()
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        filterContentForSearchText(searchController.searchBar.text!)
    }
    
    var webModalNC: UINavigationController?
    
    // MARK: - Navigation
    func revealController(_ revealController: SWRevealViewController!, willMoveTo position: FrontViewPosition) {
        if revealViewController().frontViewPosition != FrontViewPosition.left {
            reloadChannels()
        }
        
    }

    @IBAction func reloadData(_ sender: AnyObject) {
        reloadChannels()
    }
}

extension FrontViewController: UITableViewDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if searchController.isActive && ( searchController.searchBar.text != "" ) {
            return filterdAllRssArray.count
        }
        return allRSSArray.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if searchController.isActive && searchController.searchBar.text != "" {
            return filterdAllRssArray[section].rssName
        }
        return allRSSArray[section].rssName
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 90
    }
    

    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let url = URL(string: allRSSArray[indexPath.section].rssFeeds[indexPath.row].link)
        let WVC = DZNWebViewController(url: url)
        webModalNC = UINavigationController(rootViewController: WVC!)
        WVC?.supportedWebNavigationTools = DZNWebNavigationTools.all
        WVC?.supportedWebActions = DZNsupportedWebActions.DZNWebActionAll
        WVC?.showLoadingProgress = true
        WVC?.allowHistory = true
        WVC?.hideBarsWithGestures = true
        let closeButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(FrontViewController.dismissWebView))
        WVC?.navigationItem.rightBarButtonItem = closeButton
        self.present(webModalNC!, animated: true, completion: nil)
        
    }
    
    func dismissWebView() {
        webModalNC?.dismiss(animated: true, completion: nil)
    }
    
}

extension FrontViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if searchController.isActive && ( searchController.searchBar.text != "" ) {
            return filterdAllRssArray[section].rssFeeds.count
        }
        return allRSSArray[section].rssFeeds.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "FrontViewCell") as! TableViewCell
        var item = MWFeedItem()
        if searchController.isActive && searchController.searchBar.text != "" {
            item = filterdAllRssArray[indexPath.section].rssFeeds[indexPath.row]
        } else {
            item = allRSSArray[indexPath.section].rssFeeds[indexPath.row]
        }
        cell.name.text = item.title
        cell.icon.image = UIImage(named: "placeholder")
        if item.content != nil {
            let htmlContent = item.content as NSString
            var imageSource = ""
            let rangeOfString = NSMakeRange(0, htmlContent.length)
            let regex = try! NSRegularExpression(pattern: "<img.*?src=\"([^\"]*)\"", options: [])
            if htmlContent.length > 0 {
                let match = regex.firstMatch(in: htmlContent as String, options: [], range: rangeOfString)
                if match != nil {
                    let imageURL = htmlContent.substring(with: match!.rangeAt(1)) as NSString
                    if NSString(string: imageURL.lowercased).range(of: "feedburner").location == NSNotFound {
                        imageSource = imageURL as String
                    }
                }
                
            }
            
            if imageSource != "" {
                cell.icon.af_setImage(withURL: URL(string: imageSource)!)
            } else {
                cell.icon.image = UIImage(named: "placeholder")
            }
        }
        return cell
    }

}
