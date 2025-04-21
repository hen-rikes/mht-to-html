import std::io;
import std::collections::list;

const String CYAN  = "\x1B[36m";
const String RESET = "\x1B[0m";

fn bool is_file_name_valid(String *file_name, String extension) {
    DString formated_file_name;
    defer formated_file_name.free();

    formated_file_name.append(*file_name);

    if (formated_file_name.tcopy_str().contains(".\\") || formated_file_name.tcopy_str().contains("./")) {
        formated_file_name.delete(0, 2);
    }

    usz? dot_index = formated_file_name.tcopy_str().index_of(".");
    if (catch excuse = dot_index) {
        return false;
    }

    DString formated_extension;
    defer formated_extension.free();

    formated_extension.appendf(".%s", extension);

    String extension_of_file_name = formated_file_name.tcopy_str()[dot_index..formated_file_name.len()-1];
    if (extension_of_file_name != formated_extension.tcopy_str()) {
        return false;
    }

    *file_name = formated_file_name.tcopy_str();
    return true;
}

fn void main(String[] args) {
    // Creating the usage message.
    DString usage;
    usage.appendfn("%sUsage%s:", CYAN, RESET);
    usage.append("  .\\mht-to-html [input file] [output file]\n");
    usage.append("\n[input file] recieves the name of the <.html> that will be converted.\n");
    usage.append("[output file] recievs the name of file that will be outputed, that file will be a <.html> file");

    // If only the excutable is especified we print the usage.
    if (args.len <= 1) {
        io::printn(usage);
        return;
    }
    usage.free();

    // TODO: implement the gui function using file dialogs.
    //if (args[1] == "-gui") {
    //    return;
    //}

    // If input file is not valid we throw a error.
    if (!is_file_name_valid(&args[1], "mht")) {
        io::eprintn("[ERROR] File extension of input file not supported or incorrect!");
        return;
    }
    String mht_file_name = args[1];

    // If output file was not especified we return.
    if (args.len == 2) {
        io::print("Please especify the output file!");
        return;
    }

    // If output file is not valid we throw a error.
    if (!is_file_name_valid(&args[2], "html")) {
        io::eprintn("[ERROR] File extension of output file not supported or incorrect!");
        return;
    }
    String output_file_name = args[2];

    // Opening the input file(read only).
    File? input_file = file::open(mht_file_name, "r");
    if (catch excuse = input_file) {
        if (excuse == io::FILE_NOT_FOUND) {
            io::eprintn("[ERROR] Input file not found!");
            return;
        }
        io::eprint("[ERROR] Could not open input file!");
        return;
    }

    usz? input_file_size = file::get_size(mht_file_name);
    if (catch excuse = input_file_size) {
        io::printfn("[ERROR] Couldn't get size of <%s> file", input_file);
        return;
    }

    DString mht_file_content;
    defer mht_file_content.free();

    for (usz i = 0; i < input_file_size; i++) {
        char? byte = input_file.read_byte();
        if (catch excuse = byte) {
            // NOTE: There is no need to throw a error when we have reached EOF.
            if (excuse == io::EOF) {
                break;
            }

            io::eprintfn("[ERROR] Couldn't read byte from <%s> file ", mht_file_name);
            break;
        }

        mht_file_content.append_char(byte);
    }
    
    // Closing input file.
    if (catch excuse = input_file.close()) {
        io::eprintn("[ERROR] Could not close input file!");
        return;
    }


    // Saving bytes in to lines.
    List{String} lines;
    DString line_buffer;

    foreach (index, byte : mht_file_content) {
        if (byte == '\n' && byte != 0) {
            lines.push(line_buffer.tcopy_str());
            line_buffer.clear();
        }
        line_buffer.append_char(byte);
    }
    

    // Extracting the image files.
    DString boundary;
    defer boundary.free();

    usz num_of_image_files = 1;
    foreach (line : lines) {
        if (line.contains("Content-Type: image/jpeg")) {
            num_of_image_files++;
        }

        if (line.contains("  boundary=\"=_NextPart_SMP_")) {
            usz? next_part_index = line.index_of("_NextPart_SMP_");
            if (catch excuse = next_part_index) {
                io::eprintfn("[ERROR] Index of string %s not found!", "_NextPart_SMP_");
                return;
            }

            boundary.appendf("--=%s", line[next_part_index..line.len-2]);
        }
    }

    List{String} file_names;
    DString file_name_buffer;
    for (usz i = 1; i < num_of_image_files+1; i++) {
        file_name_buffer.append("Content-Location: ");
        file_name_buffer.appendf("screenshot%04d.JPEG", i);
        file_names.push(file_name_buffer.tcopy_str());
        file_name_buffer.clear();
    }
    file_name_buffer.free();

    // NOTE: Added to the end of the file to mark the end of the last image file.
    lines.push(file_names[file_names.len()-1]);

    String unwanted_line_1 = boundary.tcopy_str();
    String unwanted_line_2 = "Content-Type: image/jpeg";
    String unwanted_line_3 = "Content-Transfer-Encoding: base64";

    List{DString} images;
    defer {
        foreach (i : images) {
            i.free();
        }
    }
    DString images_buffer;

    usz current_file_name = 0;
    bool are_we_in_a_image_file = false;
    for (usz counter = 0; counter < lines.len(); counter++) {
        String* line = &lines[counter];
        if ((*line).contains(file_names[current_file_name])) {
            if (images_buffer.len() != 0) {
                images.push(images_buffer.tcopy());
                images_buffer.clear();
            }

            if (counter < lines.len()) counter += 1;
            are_we_in_a_image_file = true;
            current_file_name++;
        } 

        if (are_we_in_a_image_file) {
            if ((*line).contains(unwanted_line_1)) continue;
            if ((*line).contains(unwanted_line_2)) continue;
            if ((*line).contains(unwanted_line_3)) continue;
            if ((*line).contains(file_names[current_file_name-1])) continue;
            images_buffer.append(*line);
        }
    }
    images_buffer.free();

    // NOTE: Removing some new lines.
    foreach (&image : images) {
        (*image).delete(0, 1);
    }

    // Inserting the images files.
    DString temp_line;
    usz current_image = 0;
    foreach (&line: lines) {
        if ((*line).contains("title=\"Click to enlarge/shrink screenshot.\" src=\"")) {
            usz? src_index = (*line).index_of("src=");
            if (catch excuse = src_index) {
                io::eprintfn("[ERROR] index of string %s not found!", "src=");
                return;
            }

            temp_line.append(*line);
            usz correct_index = src_index+"src=\"".len;
            temp_line.delete_range(correct_index, correct_index+"screenshot0000.JPEG".len-1);
            String image_html_format = "data:image/png;base64,\n";
            temp_line.insert_at(correct_index, image_html_format);
            temp_line.insert_at(correct_index+image_html_format.len, images[current_image]);
            *line = temp_line.tcopy_str();

            temp_line.clear();
            current_image++;
        }
    }
    temp_line.free();

    // Extracting the main HTML file.
    String html_file;
    DString html_file_buffer;

    bool are_we_in_the_main_html_file = false;
    foreach (&line : lines) {
        if ((*line).contains("﻿<!DOCTYPE html>")) {
            *line = "<!DOCTYPE html>";
            are_we_in_the_main_html_file = true;
        }

        if ((*line).contains("</html>")) {
            html_file_buffer.append(*line);
            html_file = html_file_buffer.tcopy_str();
            line_buffer.free();
            break;
        }

        if (are_we_in_the_main_html_file) html_file_buffer.append(*line);
    }

    // Extracting the CSS file.
    String css_file;
    DString css_file_buffer;

    bool are_we_in_the_css_html_file = false;
    foreach (&line : lines) {
        if ((*line).contains("body {")) {
            are_we_in_the_css_html_file = true;
        }

        if ((*line).contains(".center-block {")) {
            for (usz i = 0; i < 5; i++) css_file_buffer.append(*(line+i));
            css_file = css_file_buffer.tcopy_str();
            break;
        }

        if (are_we_in_the_css_html_file) css_file_buffer.append(*line);
    }
    css_file_buffer.free();

    // Final HTML file.
    DString final_html_file;
    defer final_html_file;
    final_html_file.append(html_file);

    // XML.
    String xml_body_start = "<!-- This is the recorded XML data that was used in generating this page. -->";
    String xml_end_body   = "</xml>";

    usz? xml_body_start_index = html_file.rindex_of(xml_body_start);
    if (catch excuse = xml_body_start_index) {
        io::eprintfn("[ERROR] Could not locate string %s", xml_body_start);
        return;
    }

    usz? xml_end_body_index = html_file.rindex_of(xml_end_body);
    if (catch excuse = xml_end_body_index) {
        io::eprintfn("[ERROR] Could not locate string %s", xml_end_body);
        return;
    }

    // XML Removal.
    final_html_file.delete_range(xml_body_start_index, xml_end_body_index + xml_end_body.len);

    // Slide Show.
    String slide_show = "            <a href=\"slide0001.htm\">Review the recorded steps as a slide show</a>";

    usz? slide_show_index = final_html_file.tcopy_str().rindex_of(slide_show);
    if (catch excuse = slide_show_index) {
        io::eprintfn("[ERROR] Could not locate string %s", slide_show);
        return;
    }

    // Slide Show Removal.
    final_html_file.delete_range(slide_show_index, slide_show_index + slide_show.len - 1);

    // Slide Show Rewrite.
    final_html_file.insert_at(slide_show_index, "            <a href=\"\"><del>Review the recorded steps as a slide show</del></a>");

    // Inserting the CSS file.
    String css_file_marker_location = "</body>";
    usz? css_file_marker_location_index = final_html_file.tcopy_str().index_of(css_file_marker_location);
    if (catch excuse = css_file_marker_location_index) {
        io::eprintfn("[ERROR] Could not locate string %s", css_file_marker_location);
        return;
    }

    usz css_index = css_file_marker_location_index+css_file_marker_location.len;
    final_html_file.insert_at(css_index+1, "<style>\n");
    final_html_file.insert_at(
        css_index+"<style>\n".len, 
        css_file);
    final_html_file.insert_at(css_index+"<style>\n".len+css_file.len, "\n</style>");

    // Opening output file to write the html.
    File? output_file = file::open(output_file_name, "w");
    if (catch excuse = output_file) {
        if (excuse == io::ALREADY_EXISTS) {
            io::print("ALREADY_EXISTS");
            return;
        }
        io::eprint("[ERROR] Could not open output file!");
        return;
    }

    // Writing to html file. 
    usz? write_return = output_file.write(final_html_file.tcopy_str()); 
    if (catch excuse = write_return) {
        io::eprint("[ERROR] Could not write output file!");
        return;
    }
	
    io::printfn("Succesfully wrote to file %s", output_file_name);

    if (catch excuse = output_file.close()) {
        io::eprintn("[ERROR] Could not close output file!");
        return;
    }
}
