import std::io;

fn void main() {
    String file_path = "recent.mht";
    File? mht_file = file::open(file_path, "r");
    defer mht_file.close()!!;

    if (catch excuse = mht_file) {
        io::printfn("[ERROR] Couldn't open file <%s>", file_path);
        return;
    }

    //char[1024] buffer;
    //usz? idk = mht_file.read(&buffer);

    //io::printn(idk)!!;

    //foreach (b : buffer) {
    //    //io::printf("%c", b);
    //}

    usz? file_size = file::get_size(file_path);
    if (catch excuse = file_size) {
        io::printfn("[ERROR] Couldn't get file size <%s>", file_path);
        return;
    }

    DString mht_file_content;
    defer mht_file_content.free();

    for (usz i = 0; i < file_size; i++) {
        char? byte = mht_file.read_byte();
        if (catch excuse = byte) {
            io::printfn("[ERROR] Couldn't read byte from file <%s>", file_path);
            break;
        }

        mht_file_content.append_char(byte);
    }
    
    foreach (b : mht_file_content) {
        io::printf("%c", b);
    }
}
