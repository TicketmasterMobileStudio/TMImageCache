//
//  Copyright © 2017 Ticketmaster. All rights reserved.
//

import UIKit
import TMImageCache

class SimpleDataProvider: TMImageDataProvider {
    typealias Key = URL
    
    let urlSession = URLSession(configuration: .default)
    
    func image(for url: URL, completion: @escaping (ImageRequestResult) -> Void) -> CancellableImageRequest? {

        if let image = UIImage(contentsOfFile: url.path) {
            completion(.success(image))
        } else {
            completion(.failure(nil))
        }
        
        return nil
    }
}

extension URLSessionDataTask: CancellableImageRequest { }

extension URL: TMImageKeyType {

    public var imageIdentifier: String {
        return self.absoluteString
    }

}

class CollectionViewController: UICollectionViewController {

    let originalCache = TMImageCache<URL>(name: "DemoCache_Originals")
    let dataProvider = SimpleDataProvider()
    var dataSource: TMImageDataSource<URL>?
    var renderer: TMCachedImageRenderer<URL>?

    var imageURLs: [URL] = [] {
        didSet {
            self.collectionView?.reloadData()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.dataSource = TMImageDataSource(cache: originalCache, dataProvider: dataProvider)
        self.renderer = TMCachedImageRenderer(name: "DemoCache_Volatile", dataSource: dataSource!)
        
        self.imageURLs = Bundle.main.urls(forResourcesWithExtension: "jpg", subdirectory: nil) ?? []
        for url in self.imageURLs {
            let key = url
            if self.originalCache.containsObject(forKey: key) == false {
                self.originalCache.setImage(atURL: url, forKey: key)
            }
        }

        if let layout = self.collectionView?.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.itemSize = CGSize(width: self.view.bounds.width * 0.5 - layout.minimumInteritemSpacing * 0.5 - layout.sectionInset.left * 0.5 - layout.sectionInset.right * 0.5, height: self.view.bounds.width * 0.5)
        }
        self.collectionView?.reloadData()
    }

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.imageURLs.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CustomCell", for: indexPath)
        return cell
    }

    override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if let cell = cell as? CustomCell {
            let key = imageURLs[indexPath.item]
            cell.identifier = key
            cell.imageView.alpha = 1.0
            cell.imageView.image = self.renderer?.image(forKey: key, targetSize: cell.imageView.bounds.size, completion: { (key: URL, image: UIImage?) in
                guard cell.identifier == key else {
                    return
                }
                cell.imageView.image = image
                if collectionView.indexPathsForVisibleItems.contains(indexPath) {
                    cell.imageView.alpha = 0.0
                    UIView.animate(withDuration: 0.16, delay: 0.0, options: [.allowUserInteraction, .beginFromCurrentState], animations: {
                        cell.imageView.alpha = 1.0
                    }, completion: {_ in})
                }
            })
        }
    }

    override func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if let cell = cell as? CustomCell {
            cell.imageView.image = nil
            cell.identifier = nil
        }
    }
}

class CustomCell: UICollectionViewCell {

    @IBOutlet var imageView: UIImageView!
    var identifier: URL? = nil
}
