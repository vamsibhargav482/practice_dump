#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <iostream>
#include <sstream>
#include <cmath>

// Enable if you want debugging to be printed, see example below.
// Alternative, pass CFLAGS=-DDEBUG to make, make CFLAGS=-DDEBUG
#define DEBUG

// Included to get the support library
#include <calcLib.h>

#ifdef DEBUG
#define DEBUG_PRINT(x) std::cout << x << std::endl
#else
#define DEBUG_PRINT(x)
#endif

std::string perform_operation(const std::string& operation, const std::string& value1, const std::string& value2) {
    if (operation == "add") {
        return std::to_string(std::stoi(value1) + std::stoi(value2));
    } else if (operation == "sub") {
        return std::to_string(std::stoi(value1) - std::stoi(value2));
    } else if (operation == "mul") {
        return std::to_string(std::stoi(value1) * std::stoi(value2));
    } else if (operation == "div") {
        return std::to_string(std::stoi(value1) / std::stoi(value2));
    } else if (operation == "fadd") {
        return std::to_string(std::stof(value1) + std::stof(value2));
    } else if (operation == "fsub") {
        return std::to_string(std::stof(value1) - std::stof(value2));
    } else if (operation == "fmul") {
        return std::to_string(std::stof(value1) * std::stof(value2));
    } else if (operation == "fdiv") {
        return std::to_string(std::stof(value1) / std::stof(value2));
    } else {
        throw std::invalid_argument("Unknown operation");
    }
}

int main(int argc, char *argv[]) {
    /*
      Read first input, assumes <ip>:<port> syntax, convert into one string (Desthost) and one integer (port). 
      Atm, works only on dotted notation, i.e. IPv4 and DNS. IPv6 does not work if its using ':'. 
    */
    char delim[] = ":";
    char *Desthost = strtok(argv[1], delim);
    char *Destport = strtok(NULL, delim);
    // *Desthost now points to a string holding whatever came before the delimiter, ':'.
    // *Destport points to whatever string came after the delimiter. 

    /* Do magic */
    int port = atoi(Destport);
#ifdef DEBUG 
    printf("Host %s, and port %d.\n", Desthost, port);
#endif

    int sockfd;
    struct sockaddr_in serv_addr;
    struct hostent *server;

    sockfd = socket(AF_INET, SOCK_STREAM, 0);
    if (sockfd < 0) {
        std::cerr << "ERROR opening socket" << std::endl;
        return 1;
    }

    server = gethostbyname(Desthost);
    if (server == NULL) {
        std::cerr << "ERROR, no such host" << std::endl;
        return 1;
    }

    bzero((char *) &serv_addr, sizeof(serv_addr));
    serv_addr.sin_family = AF_INET;
    bcopy((char *)server->h_addr, (char *)&serv_addr.sin_addr.s_addr, server->h_length);
    serv_addr.sin_port = htons(port);

    if (connect(sockfd, (struct sockaddr *) &serv_addr, sizeof(serv_addr)) < 0) {
        std::cerr << "ERROR connecting" << std::endl;
        return 1;
    }

    DEBUG_PRINT("Connected to " << Desthost << ":" << port);

    char buffer[256];
    bzero(buffer, 256);
    read(sockfd, buffer, 255);
    std::string protocol(buffer);
    DEBUG_PRINT("Received protocol: " << protocol);

    if (protocol.find("TEXT TCP 1.0") != std::string::npos) {
        write(sockfd, "OK\n", 3);
    } else {
        close(sockfd);
        return 1;
    }

    bzero(buffer, 256);
    read(sockfd, buffer, 255);
    std::string assignment(buffer);
    DEBUG_PRINT("ASSIGNMENT: " << assignment);

    std::istringstream iss(assignment);
    std::string operation, value1, value2;
    iss >> operation >> value1 >> value2;

    std::string result = perform_operation(operation, value1, value2);
    DEBUG_PRINT("Calculated the result to " << result);

    write(sockfd, (result + "\n").c_str(), result.length() + 1);

    bzero(buffer, 256);
    read(sockfd, buffer, 255);
    std::string response(buffer);
    std::cout << response.substr(0, response.find('\n')) << " (myresult=" << result << ")" << std::endl;

    close(sockfd);
    return 0;
}