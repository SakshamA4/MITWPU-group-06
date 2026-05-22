//
//  FilmReportViewController.swift
//  FilmsPage
//
//  A professional dark-themed modal that displays a full production report
//  for a given film. Supports in-app reading and system share/export.
//

import UIKit

final class FilmReportViewController: UIViewController {

    // MARK: - Input
    var film: Film?

    // MARK: - Private State
    private var generatedText: String = ""

    // MARK: - UI
    private let backgroundView   = UIView()
    private let headerView       = UIView()
    private let filmIconLabel    = UILabel()
    private let titleLabel       = UILabel()
    private let subtitleLabel    = UILabel()
    private let closeButton      = UIButton(type: .system)
    private let shareButton      = UIButton(type: .system)
    private let divider          = UIView()
    private let scrollView       = UIScrollView()
    private let reportTextView   = UITextView()
    private let loadingContainer = UIView()
    private let spinner          = UIActivityIndicatorView(style: .large)
    private let loadingLabel     = UILabel()

    private let accentColor = UIColor(red: 90/255, green: 200/255, blue: 140/255, alpha: 1)
    private let bgColor     = UIColor(red: 10/255, green: 12/255, blue: 22/255, alpha: 1)
    private let cardColor   = UIColor(red: 17/255, green: 20/255, blue: 35/255, alpha: 1)

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupBackground()
        setupHeader()
        setupScrollContent()
        setupLoadingOverlay()
        generateReport()
    }

    // MARK: - Setup

    private func setupBackground() {
        view.backgroundColor = .clear

        // Blurred dark backdrop
        backgroundView.backgroundColor = bgColor
        backgroundView.layer.cornerRadius = 24
        backgroundView.clipsToBounds = true
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundView)

        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupHeader() {
        headerView.backgroundColor = cardColor
        headerView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.addSubview(headerView)

        // Accent top border
        let accentBar = UIView()
        accentBar.backgroundColor = accentColor
        accentBar.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(accentBar)

        // Icon
        filmIconLabel.text = "🎬"
        filmIconLabel.font = .systemFont(ofSize: 32)
        filmIconLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(filmIconLabel)

        // Title
        titleLabel.text = film?.name ?? "Film"
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(titleLabel)

        // Subtitle
        subtitleLabel.text = "PRODUCTION REPORT"
        subtitleLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        subtitleLabel.textColor = accentColor
        subtitleLabel.letterSpacing(1.8)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(subtitleLabel)

        // Close Button
        let closeCfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        closeButton.setImage(UIImage(systemName: "xmark", withConfiguration: closeCfg), for: .normal)
        closeButton.tintColor = UIColor(white: 0.7, alpha: 1)
        closeButton.backgroundColor = UIColor(white: 1, alpha: 0.08)
        closeButton.layer.cornerRadius = 16
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(closeButton)

        // Share Button
        var shareCfg = UIButton.Configuration.filled()
        shareCfg.image = UIImage(systemName: "square.and.arrow.up",
                                 withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold))
        shareCfg.title = "Export"
        shareCfg.imagePlacement = .leading
        shareCfg.imagePadding = 6
        shareCfg.baseBackgroundColor = accentColor
        shareCfg.baseForegroundColor = .black
        shareCfg.cornerStyle = .capsule
        shareButton.configuration = shareCfg
        shareButton.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)
        shareButton.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(shareButton)

        // Divider
        divider.backgroundColor = UIColor(white: 1, alpha: 0.07)
        divider.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(divider)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: backgroundView.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor),

            accentBar.topAnchor.constraint(equalTo: headerView.topAnchor),
            accentBar.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            accentBar.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            accentBar.heightAnchor.constraint(equalToConstant: 3),

            filmIconLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            filmIconLabel.topAnchor.constraint(equalTo: accentBar.bottomAnchor, constant: 20),

            titleLabel.leadingAnchor.constraint(equalTo: filmIconLabel.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: accentBar.bottomAnchor, constant: 18),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),

            closeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            closeButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 32),
            closeButton.heightAnchor.constraint(equalToConstant: 32),

            shareButton.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -10),
            shareButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            shareButton.heightAnchor.constraint(equalToConstant: 34),

            divider.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 20),
            divider.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1),
            divider.bottomAnchor.constraint(equalTo: headerView.bottomAnchor)
        ])
    }

    private func setupScrollContent() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = true
        scrollView.indicatorStyle = .white
        backgroundView.addSubview(scrollView)

        // Monospaced text view
        reportTextView.isEditable = false
        reportTextView.isSelectable = true
        reportTextView.backgroundColor = .clear
        reportTextView.textColor = UIColor(white: 0.88, alpha: 1)
        reportTextView.font = UIFont.monospacedSystemFont(ofSize: 12.5, weight: .regular)
        reportTextView.textContainerInset = UIEdgeInsets(top: 20, left: 16, bottom: 30, right: 16)
        reportTextView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(reportTextView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: backgroundView.bottomAnchor),

            reportTextView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            reportTextView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            reportTextView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            reportTextView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            reportTextView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }

    private func setupLoadingOverlay() {
        loadingContainer.backgroundColor = bgColor
        loadingContainer.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.addSubview(loadingContainer)

        spinner.color = accentColor
        spinner.startAnimating()
        spinner.translatesAutoresizingMaskIntoConstraints = false
        loadingContainer.addSubview(spinner)

        loadingLabel.text = "Compiling report…"
        loadingLabel.font = .systemFont(ofSize: 15, weight: .medium)
        loadingLabel.textColor = UIColor(white: 0.6, alpha: 1)
        loadingLabel.textAlignment = .center
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false
        loadingContainer.addSubview(loadingLabel)

        NSLayoutConstraint.activate([
            loadingContainer.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            loadingContainer.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor),
            loadingContainer.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor),
            loadingContainer.bottomAnchor.constraint(equalTo: backgroundView.bottomAnchor),

            spinner.centerXAnchor.constraint(equalTo: loadingContainer.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: loadingContainer.centerYAnchor, constant: -20),

            loadingLabel.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 14),
            loadingLabel.centerXAnchor.constraint(equalTo: loadingContainer.centerXAnchor)
        ])
    }

    // MARK: - Report Generation

    private func generateReport() {
        guard let film = film else {
            loadingContainer.isHidden = true
            reportTextView.text = "No film selected."
            return
        }

        // Generate on background thread (fast IO, no ARKit access needed)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let report = FilmReportService.shared.buildReport(for: film)
            let text   = FilmReportService.shared.formatReport(report)

            DispatchQueue.main.async {
                self.generatedText = text
                self.reportTextView.text = text
                UIView.animate(withDuration: 0.3) {
                    self.loadingContainer.alpha = 0
                } completion: { _ in
                    self.loadingContainer.isHidden = true
                    self.spinner.stopAnimating()
                }
                // Scroll to top after content loads
                self.scrollView.setContentOffset(.zero, animated: false)
            }
        }
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func shareTapped() {
        guard !generatedText.isEmpty else { return }

        let filmName = (film?.name ?? "Film")
            .replacingOccurrences(of: " ", with: "_")
        let filename = "\(filmName)_ProductionReport.txt"

        // Write to a temp file so it can be shared as an attachment
        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? generatedText.write(to: tmpURL, atomically: true, encoding: .utf8)

        let avc = UIActivityViewController(
            activityItems: [tmpURL],
            applicationActivities: nil
        )
        avc.popoverPresentationController?.sourceView = shareButton
        present(avc, animated: true)
    }
}

// MARK: - UILabel extension for letter spacing

private extension UILabel {
    func letterSpacing(_ spacing: CGFloat) {
        guard let text = text else { return }
        let attrs = NSMutableAttributedString(string: text)
        attrs.addAttribute(.kern, value: spacing, range: NSRange(location: 0, length: attrs.length))
        attributedText = attrs
    }
}
