macro "Iba1 60X Volume Analysis [F12]" {

// Step 1: Open a dialog for the user to select a directory
dir = getDirectory("Choose a Directory containing Data and to Save The Analysis");

// Extract the folder name from the full path
list = split(dir, File.separator);
chosenFolderName = list[lengthOf(list) - 1];
if (chosenFolderName == "") {
    chosenFolderName = list[lengthOf(list) - 2];
}

// Step 2: Ask user to configure channel settings
Dialog.create("Channel Configuration");
Dialog.addMessage("Please specify the channel settings for your images:");
Dialog.addNumber("Total number of channels:", 3);
Dialog.addNumber("Channel number containing Iba1 (e.g. 1, 2, 3...):", 2);
Dialog.show();
totalChannels = Dialog.getNumber();
iba1Channel   = Dialog.getNumber();

// Get the current date and time
getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
MonthNames = newArray("01","02","03","04","05","06","07","08","09","10","11","12");
formattedDate = "" + year + "_" + MonthNames[month] + "_" + dayOfMonth;

// Create output folders
analysis_folder = dir + File.separator + formattedDate + "_analysis_" + chosenFolderName;
File.makeDirectory(analysis_folder);
image_folder = analysis_folder + File.separator + "Images";
File.makeDirectory(image_folder);
ROI_folder = analysis_folder + File.separator + "ROI";
File.makeDirectory(ROI_folder);
measurements_folder = analysis_folder + File.separator + "Measurements";
File.makeDirectory(measurements_folder);

// Step 3: List all .oif files in the directory
list = getFileList(dir);
fileCount = 0;

for (i = 0; i < list.length; i++) {
    if (endsWith(list[i], ".oif")) {
        fileCount++;
        print("Processing file " + fileCount + ": " + list[i]);
        
        // Specify Bio-Formats Importer options and open the file
        openOptions = "autoscale=false color_mode=Default crop=false split_channels=true";
        run("Bio-Formats Importer", "open=[" + dir + list[i] + "] " + openOptions);
        
        // Set scale
        run("Set Scale...", "distance=4.8309 known=1 unit=micron");
        
        // Slice name analyzed
        Slice0 = getTitle();
        Slice1 = replace(Slice0, ".oif", "");
        
        // Split the channels
        run("Make Composite", "display=Composite");
        run("Split Channels");
        
        // Close all channels except the Iba1 channel
        for (c = 1; c <= totalChannels; c++) {
            if (c != iba1Channel) {
                chName = "C" + c + "-" + list[i];
                if (isOpen(chName)) {
                    selectWindow(chName);
                    close();
                }
            }
        }
        
        // Keep and process Iba1 channel
        selectWindow("C" + iba1Channel + "-" + list[i]);
        
        // Change LUT to Red
        run("Red");
        
        // Despeckle and enhance contrast with 0.35% pixel saturated
        run("Despeckle", "stack");
        run("Enhance Contrast", "saturated=0.35");
        
        // Save the modified stack
        saveAs("Tiff", image_folder + File.separator + Slice1 + "_EnhancedStack.tif");
        enhancedStackName = getTitle();
        
        // Transform to 8-bits image
        run("8-bit");
        run("Gaussian Blur...", "sigma=1 stack");
        
        // Save pre-processed image
        saveAs("Tiff", image_folder + File.separator + Slice1 + "_Preprocessed.tif");
        preprocessedName = getTitle();
        
        // Run 3D Objects Counter
        run("3D Objects Counter on GPU (CLIJx, Experimental)");
        
        // Find and select the objects map window
        objectsMapName = "Objects map of " + Slice1 + "_Preprocessed.tif (experimental, clij)";
        
        selectWindow(objectsMapName);
        
        run("Synchronize Windows");
        
        // Let user examine the GPU results first
        waitForUser("Review GPU Objects", "Examine the GPU-detected objects map.\nNavigate through the stack to verify quality.\n\nClick OK when ready to proceed.");
        
        // Ask user if GPU results are acceptable
        Dialog.create("GPU Object Detection Quality");
        Dialog.addMessage("Are the GPU-detected objects acceptable?");
        Dialog.addChoice("Results are good", newArray("Yes", "No"));
        Dialog.show();
        useGPUResults = Dialog.getChoice();
        
        // If GPU results are not good, use classic 3D Objects Counter
        if (useGPUResults == "No") {
            // Close the GPU objects map
            selectWindow(objectsMapName);
        
            // Reselect the preprocessed image
            selectWindow(preprocessedName);
            
            // Run classic 3D Objects Counter
            run("3D Objects Counter");
            
            // Update objects map name for classic method
            objectsMapName = "Objects map of " + Slice1 + "_Preprocessed.tif";
        }
        
        // Select and save the objects map
        selectWindow(objectsMapName);
        saveAs("Tiff", image_folder + File.separator + Slice1 + "_ObjectsMapRaw.tif");
        
        // Initialize 3D Manager
        run("3D Manager");
        Ext.Manager3D_AddImage();
        
        // Wait for the user to verify ROIs
        waitForUser("Verify ROIs", "Review the detected objects.\nModify if needed, then click OK.");
        
        // Process ROIs
        Ext.Manager3D_SelectAll();
        Ext.Manager3D_Rename("Microglia");
        Ext.Manager3D_Save(ROI_folder + File.separator + Slice1 + "_Microglia_ROIs.zip");
        
        // Measurements
        Ext.Manager3D_Measure();
        Ext.Manager3D_SaveResult("M", measurements_folder + File.separator + Slice1 + "_ResultsMeasure.csv");
        
        // Quantification
        Ext.Manager3D_Quantif();
        Ext.Manager3D_SaveResult("Q", measurements_folder + File.separator + Slice1 + "_ResultsQuantif.csv");
        
        // Clear ROIs and close result windows for next iteration
        Ext.Manager3D_Reset();
        
    }
    
    // Close all windows for this file
    while (nImages > 0) {
        selectImage(nImages);
        close();
    }
    
    // Garbage collection
    run("Collect Garbage");
    
    print("Completed processing: " + list[i]);
    }
}

print("\\Clear");
print("=== Analysis Complete ===");
print("Total files processed: " + fileCount);
print("Results saved in: " + analysis_folder);
showMessage("Analysis Complete", "Processed " + fileCount + " files.\n\nResults saved in:\n" + analysis_folder);
}
