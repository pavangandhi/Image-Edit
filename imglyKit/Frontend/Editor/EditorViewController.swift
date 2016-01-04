//
//  EditorViewController.swift
//  imglyKit
//
//  Created by Sascha Schwabbauer on 07/04/15.
//  Copyright (c) 2015 9elements GmbH. All rights reserved.
//

import UIKit

internal let kPhotoProcessorQueue = dispatch_queue_create("ly.img.SDK.PhotoProcessor", DISPATCH_QUEUE_SERIAL)

@objc(IMGLYEditorViewControllerOptions) public class EditorViewControllerOptions: NSObject {

    ///  Defaults to 'Editor'
    public let title: String?

    /// The viewControllers backgroundColor. Defaults to the configurations
    /// global background color.
    public let backgroundColor: UIColor?

    /**
     A configuration closure to configure the given left bar button item.
     Defaults to a 'Cancel' in the apps tintColor or 'Back' when presented within
     a navigation controller.
     */
    public let leftBarButtonConfigurationClosure: BarButtonItemConfigurationClosure

    /**
     A configuration closure to configure the given done button item.
     Defaults to 'Editor' in the apps tintColor.
     */
    public let rightBarButtonConfigurationClosure: BarButtonItemConfigurationClosure

    /// Controls if the user can zoom the preview image. Defaults to **true**.
    public let allowsPreviewImageZoom: Bool

    convenience override init() {
        self.init(editorBuilder: EditorViewControllerOptionsBuilder())
    }

    init(editorBuilder: EditorViewControllerOptionsBuilder) {
        title = editorBuilder.title
        backgroundColor = editorBuilder.backgroundColor
        leftBarButtonConfigurationClosure = editorBuilder.leftBarButtonConfigurationClosure
        rightBarButtonConfigurationClosure = editorBuilder.rightBarButtonConfigurationClosure
        allowsPreviewImageZoom = editorBuilder.allowsPreviewImageZoom
        super.init()
    }
}

@objc(IMGLYEditorViewControllerOptionsBuilder) public class EditorViewControllerOptionsBuilder: NSObject {
    ///  Defaults to 'Editor'
    public lazy var title: String? = "Editor"

    /// The viewControllers backgroundColor. Defaults to the configurations
    /// global background color.
    public var backgroundColor: UIColor?

    /**
     A configuration closure to configure the given left bar button item.
     Defaults to a 'Cancel' in the apps tintColor or 'Back' when presented within
     a navigation controller.
     */
    public lazy var leftBarButtonConfigurationClosure: BarButtonItemConfigurationClosure = { _ in }

    /**
     A configuration closure to configure the given done button item.
     Defaults to 'Editor' in the apps tintColor.
     */
    public lazy var rightBarButtonConfigurationClosure: BarButtonItemConfigurationClosure = { _ in }

    /// Controls if the user can zoom the preview image. Defaults to **true**.
    public lazy var allowsPreviewImageZoom = true
}

@objc(IMGLYEditorViewController) public class EditorViewController: UIViewController {

    // MARK: - Properties

    var configuration: Configuration = Configuration()

    public var shouldShowActivityIndicator = true

    var options: EditorViewControllerOptions {
        // Must be implemented in subclass
        return EditorViewControllerOptions()
    }

    public var updating = false {
        didSet {
            if shouldShowActivityIndicator {
                dispatch_async(dispatch_get_main_queue()) {
                    if self.updating {
                        self.activityIndicatorView.startAnimating()
                    } else {
                        self.activityIndicatorView.stopAnimating()
                    }
                }
            }
        }
    }

    public var lowResolutionImage: UIImage?

    public private(set) lazy var previewImageView: ZoomingImageView = {
        let imageView = ZoomingImageView()
        imageView.backgroundColor = self.currentBackgroundColor
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.userInteractionEnabled = self.enableZoomingInPreviewImage
        return imageView
        }()

    public private(set) lazy var bottomContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = self.currentBackgroundColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var activityIndicatorView: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(activityIndicatorStyle: .WhiteLarge)
        view.hidesWhenStopped = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    var currentBackgroundColor: UIColor {
        if let customBackgroundColor = options.backgroundColor {
            return customBackgroundColor
        }

        return configuration.backgroundColor
    }

    // MARK: - Initalization

    /**
    This is the designated initializer that accepts an Configuration

    - parameter configuration: An Configuration object

    - returns: An initialized EditorViewController
    */
    init(configuration: Configuration) {
        super.init(nibName: nil, bundle: nil)
        self.configuration = configuration
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    // MARK: - UIViewController

    override public func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.title = options.title

        configureNavigationItems()
        configureViewHierarchy()
        configureViewConstraints()
    }

    public override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return .LightContent
    }

    public override func prefersStatusBarHidden() -> Bool {
        return true
    }

    public override func shouldAutorotate() -> Bool {
        return false
    }

    public override func preferredInterfaceOrientationForPresentation() -> UIInterfaceOrientation {
        return .Portrait
    }

    // MARK: - Configuration

    private func configureNavigationItems() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Done, target: self, action: "tappedDone:")
        options.rightBarButtonConfigurationClosure(navigationItem.rightBarButtonItem!)

        if let leftNavigationItem = navigationItem.leftBarButtonItem {
            options.leftBarButtonConfigurationClosure(leftNavigationItem)
        }
    }

    private func configureViewHierarchy() {
        if let navBar = self.navigationController?.navigationBar {
            navBar.barTintColor = currentBackgroundColor
        }

        view.backgroundColor = currentBackgroundColor

        view.addSubview(previewImageView)
        view.addSubview(bottomContainerView)
        previewImageView.addSubview(activityIndicatorView)
    }

    private func configureViewConstraints() {
        let views: [String: AnyObject] = [
            "previewImageView" : previewImageView,
            "bottomContainerView" : bottomContainerView,
            "topLayoutGuide" : topLayoutGuide
        ]

        let metrics: [String: AnyObject] = [
            "bottomContainerViewHeight" : 100
        ]

        view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("|[previewImageView]|", options: [], metrics: nil, views: views))
        view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("|[bottomContainerView]|", options: [], metrics: nil, views: views))
        view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:[topLayoutGuide][previewImageView][bottomContainerView(==bottomContainerViewHeight)]|", options: [], metrics: metrics, views: views))

        previewImageView.addConstraint(NSLayoutConstraint(item: activityIndicatorView, attribute: .CenterX, relatedBy: .Equal, toItem: previewImageView, attribute: .CenterX, multiplier: 1, constant: 0))
        previewImageView.addConstraint(NSLayoutConstraint(item: activityIndicatorView, attribute: .CenterY, relatedBy: .Equal, toItem: previewImageView, attribute: .CenterY, multiplier: 1, constant: 0))
    }

    var enableZoomingInPreviewImage: Bool {
        return options.allowsPreviewImageZoom
    }

    // MARK: - Actions

    public func tappedDone(sender: UIBarButtonItem?) {
        // Subclasses must override this
    }

}
