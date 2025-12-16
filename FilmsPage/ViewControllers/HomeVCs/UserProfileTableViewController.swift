//
// UserProfileTableViewController.swift
// FilmsPage
//
// Child VC: Manages the Static Table Content and handles row taps.
//

import UIKit

class UserProfileTableViewController: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // CRUCIAL: Set the background to clear so the dark color of the parent 'cardView' shows through.
        tableView.backgroundColor = .clear
        
        // Remove the extra header space typical of Grouped/Inset Grouped styles
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.size.width, height: 0.01))
        
        // Disable scrolling on the inner table view
        tableView.isScrollEnabled = false
    }

    // MARK: - Table View Delegate (Handling Taps on Static Cells)

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        // Map the taps to the rows you defined: (2 rows in section 0, 3 rows in section 1)
        if indexPath.section == 0 {
            switch indexPath.row {
            case 0: print("Section 0, Row 0 (e.g., Personal Details) tapped")
            case 1: print("Section 0, Row 1 (e.g., Shared Projects) tapped")
            default: break
            }
        }
        else if indexPath.section == 1 {
            switch indexPath.row {
            case 0: print("Section 1, Row 0 (e.g., Settings) tapped")
            case 1: print("Section 1, Row 1 (e.g., Help) tapped")
            case 2: print("Section 1, Row 2 (e.g., About us) tapped")
            default: break
            }
        }
    }
    // UserProfileTableViewController.swift

    // MARK: - UNNECESSARY METHODS REMOVED FOR STATIC CELLS
    // The following data source methods are automatically handled by the Storyboard.

    /*
    override func numberOfSections(in tableView: UITableView) -> Int { return 0 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { return 0 }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell { return cell }
    */
}
