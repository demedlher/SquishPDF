using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using PdfSharp.Pdf;
using PdfSharp.Pdf.IO;
using System;
using System.IO;
using System.Threading.Tasks;
using Windows.Storage;
using Windows.Storage.Pickers;

namespace PDFConverter.Windows
{
    public sealed partial class MainWindow : Window
    {
        private int selectedDpi = 150; // Default to medium quality

        public MainWindow()
        {
            this.InitializeComponent();
            Title = "PDF Converter";
        }

        private void CompressionOption_Checked(object sender, RoutedEventArgs e)
        {
            if (sender is RadioButton radioButton)
            {
                selectedDpi = radioButton.Name switch
                {
                    "SmallOption" => 72,
                    "MediumOption" => 150,
                    "LargeOption" => 300,
                    _ => 150
                };
            }
        }

        private void DropZone_DragOver(object sender, DragEventArgs e)
        {
            e.AcceptedOperation = Windows.ApplicationModel.DataTransfer.DataPackageOperation.Copy;
        }

        private async void DropZone_Drop(object sender, DragEventArgs e)
        {
            if (e.DataView.Contains(Windows.ApplicationModel.DataTransfer.StandardDataFormats.StorageItems))
            {
                var items = await e.DataView.GetStorageItemsAsync();
                if (items.Count > 0 && items[0] is StorageFile file && file.FileType.ToLower() == ".pdf")
                {
                    await ProcessPdfFile(file);
                }
                else
                {
                    ShowError("Please drop a PDF file.");
                }
            }
        }

        private async Task ProcessPdfFile(StorageFile inputFile)
        {
            try
            {
                ShowProgress(true);
                HideError();

                // Create output file picker
                var savePicker = new FileSavePicker();
                savePicker.SuggestedStartLocation = PickerLocationId.DocumentsLibrary;
                savePicker.FileTypeChoices.Add("PDF files", new[] { ".pdf" });
                savePicker.SuggestedFileName = $"{Path.GetFileNameWithoutExtension(inputFile.Name)}_compressed";

                // Get the window handle
                var hwnd = WinRT.Interop.WindowNative.GetWindowHandle(this);
                WinRT.Interop.InitializeWithWindow.Initialize(savePicker, hwnd);

                StorageFile outputFile = await savePicker.PickSaveFileAsync();
                if (outputFile != null)
                {
                    using (var inputStream = await inputFile.OpenStreamForReadAsync())
                    using (var outputStream = await outputFile.OpenStreamForWriteAsync())
                    {
                        // Load the PDF
                        var document = PdfReader.Open(inputStream, PdfDocumentOpenMode.Import);
                        
                        // Create new document with compression settings
                        var outputDocument = new PdfDocument();
                        foreach (var page in document.Pages)
                        {
                            outputDocument.AddPage(page);
                        }

                        // Save with compression
                        outputDocument.Options.CompressContentStreams = true;
                        outputDocument.Options.EnableCcittCompressionForBilevelImages = true;
                        outputDocument.Options.UseFlateDecoderForJpegImages = true;
                        outputDocument.Save(outputStream);
                    }
                }
            }
            catch (Exception ex)
            {
                ShowError($"Error processing PDF: {ex.Message}");
            }
            finally
            {
                ShowProgress(false);
            }
        }

        private void ShowProgress(bool show)
        {
            ProgressIndicator.Visibility = show ? Visibility.Visible : Visibility.Collapsed;
        }

        private void ShowError(string message)
        {
            ErrorText.Text = message;
            ErrorText.Visibility = Visibility.Visible;
        }

        private void HideError()
        {
            ErrorText.Visibility = Visibility.Collapsed;
        }
    }
} 