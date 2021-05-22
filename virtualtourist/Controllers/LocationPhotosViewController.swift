//
//  LocationPhotosViewController.swift
//  virtualtourist
//
//  Created by Brian Hamilton on 5/5/21.
//

import Foundation
import UIKit
import MapKit
import CoreData

class LocationPhotosViewController: UIViewController, MKMapViewDelegate, NSFetchedResultsControllerDelegate {
    
    @IBOutlet weak var newCollectionButton: UIButton!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    var pin: Pin!
//    var photoAlbum = [Photo]()
    var dataController:DataController!
    var numberOfPages = 1
    var lastPage = 1
    let reuseIdentifier = "PhotoCollectionViewCell"
    var fetchedResultsController: NSFetchedResultsController<Photo>!
    var span = MKCoordinateSpan()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.delegate = self
        collectionView.dataSource = self
        mapView.delegate = self
        mapView.isScrollEnabled = false
        mapView.isZoomEnabled = false
        mapView.isUserInteractionEnabled = false
        if let pin = pin {
            let latitude = pin.latitude
            let longitude =  pin.longitude
            let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            let region = MKCoordinateRegion(center: center, span: span)
            let annotation = MKPointAnnotation()
            annotation.coordinate = center
            self.mapView.addAnnotation((annotation))
            mapView.setRegion(region, animated: true)
        }
        if pin.photos?.count == 0 {
            print("no photos, should be downloading URL's")
            downloadImageURLs(page: 1, completion: {
                self.collectionView.reloadData()
                if self.pin.photos?.count == 0 {
                    self.noPhotos()
                }
            })
        }
        let space:CGFloat = 3.0
        let dimension = (view.frame.size.width - (2 * space)) / 3.0
        flowLayout.minimumInteritemSpacing = space
        flowLayout.minimumLineSpacing = space
        flowLayout.itemSize = CGSize(width: dimension, height: dimension)
        setupFetchRequestController()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        fetchedResultsController = nil
    }
    
    func noPhotos(){
        let alert = UIAlertController(title: "", message: "No photos were found at this location", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alert, animated: true)
    }
    
    fileprivate func setupFetchRequestController() {
        let fetchRequest:NSFetchRequest<Photo> = Photo.fetchRequest()
//        let predicate = NSPredicate(format: "pin == %@", argumentArray: [pin!])
        let predicate = NSPredicate(format: "pin == %@", pin)
        fetchRequest.predicate = predicate
        let sortDescriptor = NSSortDescriptor(key: "url", ascending: true)
        fetchRequest.sortDescriptors = [sortDescriptor]
//        if let result = try? dataController.viewContext.fetch(fetchRequest) {
//            photoAlbum = result
//            self.collectionView.reloadData()
//        }
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: dataController.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        fetchedResultsController.delegate = self
        do {
            try fetchedResultsController.performFetch()
        } catch {
            fatalError("The fetch could not be performed \(error.localizedDescription)")
        } // end catch
    }
    
    @IBAction func newCollectionButtonTapped(_ sender: Any) {
        newCollectionButton.isEnabled = false
        if let objects = self.fetchedResultsController.fetchedObjects {
            let photosToDelete = self.collectionView.indexPathsForVisibleItems
            collectionView.deleteItems(at: photosToDelete)
            for object in objects {
                self.dataController.viewContext.delete(object)
                try? self.dataController.viewContext.save()
            }
        }
        activityIndicator.startAnimating()
//        photoAlbum.removeAll()
        if lastPage == numberOfPages {
            lastPage = 0
        }
        downloadImageURLs(page: lastPage + 1, completion: {
            self.lastPage = self.lastPage + 1
            self.setupFetchRequestController()
            if let newPhotos = self.fetchedResultsController.fetchedObjects {
                for newPhoto in newPhotos {
                    let newPhotoURL = newPhoto.url!
                    FlickrClient.downloadImage(path: URL(string: newPhotoURL)!) { data, error in
                        guard let data = data else {
                            return
                        }
                        newPhoto.photo = data
                        newPhoto.pin = self.pin
                        self.dataController.save()
//                        DispatchQueue.main.async {
//                            self.collectionView.reloadData()
//                        } // end async
                    } // end downloadImage closure
                } // end for loop
            }
//            DispatchQueue.main.async {
//                self.activityIndicator.stopAnimating()
//                self.newCollectionButton.isEnabled = true
//            }
        })
        DispatchQueue.main.async {
            self.activityIndicator.stopAnimating()
            self.newCollectionButton.isEnabled = true
            self.collectionView.reloadData()
        }
    }
    
    func downloadImageURLs(page: Int, completion: @escaping () -> Void) {
        let flickrResponseURL = FlickrClient.getPlacesURL(latitude: pin.latitude, longitude: pin.longitude, perPage: 15, page: page)
        print("flickrResponseURL: \(flickrResponseURL)")
        FlickrClient.getImageIDs(url: flickrResponseURL, latitude: pin.latitude, longitude: pin.longitude, perPage: 15, page: page) { bool, data, error in
            if bool {
                self.numberOfPages = data!.photos.pages
                for photo in data!.photos.photo {
                    let photoURL = FlickrClient.generatePhotoURL(photo: photo)
                    print("photoURL: \(photoURL)")
                    let photo = Photo(context: self.dataController.viewContext)
                    photo.url = photoURL
                    photo.pin = self.pin
                    self.dataController.save()
                    print("photos.count: \(self.pin.photos?.count)")
                } // end for loop
                DispatchQueue.main.async {
                    self.collectionView.reloadData()
                }
            } else {
                print("error getting image id's")
                print(error?.localizedDescription ?? "error")
            } // end else
        } // end getImageIDs closure
    } // end initial image download
}

extension LocationPhotosViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
//        return photoAlbum.count
        return fetchedResultsController.fetchedObjects!.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        //
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! PhotoCollectionViewCell
        let photo = fetchedResultsController.object(at: indexPath)
//        let photo = photoAlbum[indexPath.row]
        if let photo = photo.photo {
            cell.photoImageView.image = UIImage(data: photo)
        } else {
//            let photoURL = photoAlbum[indexPath.row].url!
            if let url = photo.url {
                let photoURL = url
                FlickrClient.downloadImage(path: URL(string: photoURL)!) { data, error in
                    guard let data = data else {
                        return
                    }
                    photo.photo = data
                    photo.pin = self.pin
                    self.dataController.save()
                    DispatchQueue.main.async {
                        cell.photoImageView.image = UIImage(data: photo.photo!)
                    }
                }
            }
            
        } // end else

        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
//        let photo = photoAlbum[indexPath.row]
        let photo = fetchedResultsController.object(at: indexPath)
        dataController.viewContext.delete(photo)
//        photoAlbum.remove(at: indexPath.row)
        try? dataController.viewContext.save()
        DispatchQueue.main.async {
            collectionView.deleteItems(at: [indexPath])
            collectionView.reloadData()
        }
        
    }
}


