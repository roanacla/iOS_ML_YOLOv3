//
//  SnapsTableViewController.swift
//  iOS_ML_YOLOv3
//
//  Created by Roger Navarro on 11/1/20.
//

import UIKit
import CoreData

class SnapsTableViewController: UITableViewController {
  
  //MARK: - Properties
  var context: NSManagedObjectContext?
  private lazy var fetchedResultsController: NSFetchedResultsController<Snap> = {
    let fetchRequest: NSFetchRequest<Snap> = Snap.fetchRequest()
    fetchRequest.fetchLimit = 20
    
    let sortDescriptor = NSSortDescriptor(key: "snapID", ascending: false)
    fetchRequest.sortDescriptors = [sortDescriptor]
    
    let frc = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.context!, sectionNameKeyPath: nil, cacheName: nil)
    frc.delegate = self
    return frc
  }()
  
  //MARK: - IBOutlets
  
  //MARK: - View Life Cycle
  override func viewDidLoad() {
    super.viewDidLoad()
    
    do {
      try fetchedResultsController.performFetch()
      tableView.reloadData()
    } catch {
      fatalError("Core Data fetch error")
    }
  }
  

  // MARK: - Navigation
  
  // In a storyboard-based application, you will often want to do a little preparation before navigation
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    switch segue.identifier {
    case "TakeSnap":
      if let controller = segue.destination as? CameraViewController {
        handleShowCameraSegue(cameraViewController: controller)
      }
    default: return
    }
  }
  
  private func handleShowCameraSegue(cameraViewController: CameraViewController) {
    cameraViewController.context = self.context
  }
  
  // MARK: - IBActions
  @IBAction func snapObjects(_ sender: Any) {
    
  }
  
}

extension SnapsTableViewController: NSFetchedResultsControllerDelegate {
  func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    tableView.beginUpdates()
  }
  
  func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
    guard let snap = anObject as? Snap else { return }
    
    switch type {
    case .insert:
      guard let newIndexPath = newIndexPath else { return }
      tableView.insertRows(at: [newIndexPath], with: .fade)
    case .delete:
      guard let indexPath = indexPath else { return }
      tableView.deleteRows(at: [indexPath], with: .fade)
    case .update:
      guard let indexPath = indexPath, let cell = tableView.cellForRow(at: indexPath) else { return }
      cell.textLabel?.text = snap.snapID?.description
    default: return
    }
  }
  
  func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    tableView.endUpdates()
  }
}

//MARK: - TableViewControllerDelegate
extension SnapsTableViewController {
  // MARK: - Table view data source
  
  override func numberOfSections(in tableView: UITableView) -> Int {
    return fetchedResultsController.sections?.count ?? 0
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    guard let sectionInfo = fetchedResultsController.sections?[section] else { return 0 }
    return sectionInfo.numberOfObjects
  }
  
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "SnapCell", for: indexPath)
    let snap = fetchedResultsController.object(at: indexPath)
    cell.textLabel?.text = "\(snap.objects?.count ?? 0) objects found"
    if let photo = snap.photo {
      cell.imageView?.image = UIImage(data: photo)
    }
    return cell
  }
  
  /*
   // Override to support conditional editing of the table view.
   override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
   // Return false if you do not want the specified item to be editable.
   return true
   }
   */
  
  /*
   // Override to support editing the table view.
   override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
   if editingStyle == .delete {
   // Delete the row from the data source
   tableView.deleteRows(at: [indexPath], with: .fade)
   } else if editingStyle == .insert {
   // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
   }
   }
   */
}
