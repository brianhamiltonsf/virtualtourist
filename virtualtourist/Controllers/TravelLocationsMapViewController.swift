//
//  ViewController.swift
//  virtualtourist
//
//  Created by Brian Hamilton on 4/27/21.
//

import UIKit
import MapKit
import CoreData

class TravelLocationsMapViewController: UIViewController, MKMapViewDelegate, UIGestureRecognizerDelegate, NSFetchedResultsControllerDelegate {
    
    @IBOutlet weak var mapView: MKMapView!
    var latitude: Double?
    var longitude: Double?
    var pins:[Pin]?
    var dataController:DataController = (UIApplication.shared.delegate as! AppDelegate).dataController
    
    var fetchedResultsController: NSFetchedResultsController<Pin>!
        
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        mapView.delegate = self
        setupFetchRequestController()
        setupMap()
        let gestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleTap(gestureRecognizer:)))
        gestureRecognizer.delegate = self
        gestureRecognizer.minimumPressDuration = 0.75
        mapView.addGestureRecognizer(gestureRecognizer)
        fetchPins()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    fileprivate func setupFetchRequestController() {
        let fetchRequest:NSFetchRequest<Pin> = Pin.fetchRequest()
        let sortDescriptor = NSSortDescriptor(key: "latitude", ascending: true)
        fetchRequest.sortDescriptors = [sortDescriptor]
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: dataController.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        fetchedResultsController.delegate = self
        do {
            try fetchedResultsController.performFetch()
        } catch {
            fatalError("The fetch could not be performed \(error.localizedDescription)")
        }
    }
    
    // MARK: Map functions
    
    // Retrieves the last used location and span and applies it to the map
    fileprivate func setupMap() {
        if let latitude = UserDefaults.standard.object(forKey: "Latitude"), let longitude = UserDefaults.standard.object(forKey: "Longitude"), let latitudeDelta = UserDefaults.standard.object(forKey: "LatitudeDelta"), let longitudeDelta = UserDefaults.standard.object(forKey: "LongitudeDelta") {
            let center = CLLocationCoordinate2D(latitude: latitude as? Double ?? 37.132840, longitude: longitude as? Double ?? -95.78557)
            let span = MKCoordinateSpan(latitudeDelta: latitudeDelta as? Double ?? 92.89541990646822, longitudeDelta: longitudeDelta as? Double ?? 57.723779800666776)
            let region = MKCoordinateRegion(center: center, span: span)
            mapView.setRegion(region, animated: true)
        }
    }
    
    // Load all pins from the db onto the map
    func fetchPins(){
        do {
            self.pins = try dataController.viewContext.fetch(Pin.fetchRequest())
            DispatchQueue.main.async {
                if let pins = self.pins {
                    for pin in pins {
                        let coordinate = CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)
                        let annotation = MKPointAnnotation()
                        annotation.coordinate = coordinate
                        self.mapView.addAnnotation((annotation))
                    } // end for loop
                } // end unwrapping pins
            } // end dispatchqueue
        } // end do block
        catch {
            print("error retrieving pins")
        }
    }
    
    // Store the map location and span whenever the map is moved
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        UserDefaults.standard.set(mapView.centerCoordinate.latitude, forKey: "Latitude")
        UserDefaults.standard.set(mapView.centerCoordinate.longitude, forKey: "Longitude")
        UserDefaults.standard.set(mapView.region.span.latitudeDelta, forKey: "LatitudeDelta")
        UserDefaults.standard.set(mapView.region.span.longitudeDelta, forKey: "LongitudeDelta")
    }
    
    // MARK: Pin functions
    
    // Add new pin
    @objc func handleTap(gestureRecognizer: UILongPressGestureRecognizer) {
        let location = gestureRecognizer.location(in: mapView)
        let coordinate = mapView.convert(location, toCoordinateFrom: mapView)
        if gestureRecognizer.state == .began {
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            mapView.addAnnotation(annotation)
            let newPin = Pin(context: dataController.viewContext)
            newPin.latitude = coordinate.latitude
            newPin.longitude = coordinate.longitude
            do {
                try dataController.viewContext.save()
            } catch {
                print("save failed")
            }
        }
    }
    
    // Click on existing pin
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        view.isSelected = false
        self.latitude = (view.annotation?.coordinate.latitude)!
        self.longitude = (view.annotation?.coordinate.longitude)!
        do {
        self.pins = try dataController.viewContext.fetch(Pin.fetchRequest())
        } catch {
            print("error retrieving pins")
            return
        }
        DispatchQueue.main.async {
            if let pins = self.pins {
                guard let indexPath = pins.firstIndex(where: { (pin) -> Bool in
                    pin.latitude == self.latitude && pin.longitude == self.longitude
                }) else {
                    return
                }
                let selectedPin = pins[indexPath]
                let locationPhotosViewController = self.storyboard!.instantiateViewController(identifier: "LocationPhotosViewController") as! LocationPhotosViewController
                locationPhotosViewController.pin = selectedPin
                locationPhotosViewController.dataController = self.dataController
                locationPhotosViewController.span = MKCoordinateSpan(latitudeDelta: mapView.region.span.latitudeDelta, longitudeDelta: mapView.region.span.longitudeDelta)
                let backButton = UIBarButtonItem()
                backButton.title = "OK"
                self.navigationItem.backBarButtonItem = backButton
                self.navigationController?.pushViewController(locationPhotosViewController, animated: false)
            }
        }
    }
    
}

