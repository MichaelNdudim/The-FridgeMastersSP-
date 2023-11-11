//import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fridgemasters/inventory.dart';
import 'package:fridgemasters/widgets/taskbar.dart';
import 'package:fridgemasters/widgets/backgrounds.dart';
import 'package:fridgemasters/nutritionpage.dart';
import 'package:fridgemasters/widgets/textonlybutton.dart';
import 'package:fridgemasters/settings.dart';
import 'package:fridgemasters/notificationlist.dart';
import 'package:fridgemasters/foodentry.dart'; // Import the food entry page
import 'package:fridgemasters/Services/database_service.dart';
import 'package:fridgemasters/Services/storage_service.dart';
import 'package:fridgemasters/Services/deleteitem.dart';
import 'package:path_drawing/path_drawing.dart';
import 'package:uuid/uuid.dart';

String convertToDisplayFormat(String date) {
  var parts = date.split('-');
  if (parts.length == 3) {
    return '${parts[1]}/${parts[2]}/${parts[0]}'; // Convert to MM/DD/YYYY
  }
  return date; // Return the original string if the format isn't as expected
}


class ExpiringItemTile extends StatefulWidget {
  final String expirationDate;
  final String purchaseDate;
  final Widget child;

  ExpiringItemTile({
    required this.expirationDate,
    required this.purchaseDate,
    required this.child,
  });

  @override
  _ExpiringItemTileState createState() => _ExpiringItemTileState();
}

class _ExpiringItemTileState extends State<ExpiringItemTile> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: false);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Widget _nonExpiringBorder(Widget child) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Color.fromARGB(255, 20, 220, 27), width: 2.0),
      ),
      child: child,
    );
  }

  Widget _closeToExpiringBorder(Widget child) {
  return AnimatedBuilder(
      animation: _animationController,
      builder: (context, _) {
        final color = ColorTween(
          begin: Colors.yellow,
          end: Color.fromARGB(255, 103, 98, 30),
        ).lerp(_animationController.value);
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: color!, width: 2.0),
          ),
          child: child,
        );
      },
    );
  }
 Widget _expiredBorder(Widget child) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, _) {
        final color = ColorTween(
          begin: Color.fromARGB(255, 177, 21, 21),
          end: Color.fromARGB(255, 103, 98, 30),
        ).lerp(_animationController.value);
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: color!, width: 2.0),
          ),
          child: child,
        );
      },
    );
  }

  Widget _getExpirationBorder(String expirationDate, String purchaseDate, Widget child) {
    final expiryDate = DateTime.parse(expirationDate);
    final currentDate = DateTime.now();
    final currentDateAtMidnight = DateTime(currentDate.year, currentDate.month, currentDate.day);
    final purchaseDateParsed = DateTime.parse(purchaseDate);
    final daysLeft = expiryDate.difference(currentDateAtMidnight).inDays;

    if (expiryDate.isBefore(currentDateAtMidnight) || expiryDate.isBefore(purchaseDateParsed)) {
      return _expiredBorder(child);
    } else if (daysLeft <= 7) {
      return _closeToExpiringBorder(child);
    } else {
      return _nonExpiringBorder(child);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _getExpirationBorder(widget.expirationDate, widget.purchaseDate, widget.child);
  }
}

class YourWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Get today's date
    String currentDate = DateTime.now().toString().split(' ')[0]; // YYYY-MM-DD format

    return Column(
      children: [
        // Today's Date Centered
        Text(
          'Today\'s Date: $currentDate',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 10), // Spacing

        // Legend
      ],
    );
  }
}

class HomePage extends StatefulWidget {

  
  final List<Map<String, dynamic>> fridgeItems;

  const HomePage({Key? key, required this.fridgeItems}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Map<String, dynamic>> fridgeItems = [];
  final TextEditingController _searchController = TextEditingController();
  final DatabaseService dbService = DatabaseService();

  @override
  void initState() {
    super.initState();
    _loadFridgeItems();
  }

  void _loadFridgeItems() async {
    try {
      final storageService = StorageService();

      // Fetch stored userId from storage
      String? userID = await storageService.getStoredUserId();

      if (userID != null) {
        List<Map<String, dynamic>> loadedItems =
            await dbService.getUserInventory(userID);

// Map the loadedItems to the expected format
        List<Map<String, dynamic>> formattedItems = loadedItems.map((item) {
          String imageUrl = item['imageUrl'] ?? 'images/default_image.png'; // Use the image URL from the database if available
          return {
            'itemId': item['itemId'], // Include the itemId
            'name': item['productName'],
            'quantity': '${item['quantity']}',
            'purchaseDate': item['dateOfPurchase']
                .split(" ")[0], // Only take the date part, exclude the time
            'expirationDate': item['expirationDate']
                .split(" ")[0], // Only take the date part, exclude the time

            'imageUrl':
                item['imageUrl'], // Keep as default or adjust as necessary
          };
        }).toList();
print('Formatted Items: $formattedItems'); // Print the formattedItems list
        setState(() {
          widget.fridgeItems.addAll(formattedItems);
        });
      } else {
        print('No user ID found in storage.');
      }
    } catch (error) {
      print('Error fetching items: $error');
      // Handle any errors, maybe show a notification to the user
    }
  }

  void _navigateToAddItem() async {
    final FoodItem? newFoodItem = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FoodEntry(onFoodItemAdded: (foodItem) {
          Navigator.pop(
              context, foodItem); // Return the food item back to this page
        }),
      ),
    );

    if (newFoodItem != null) {
      setState(() {
        widget.fridgeItems.add({
          'ItemID': newFoodItem.itemId,
          'name': newFoodItem.name,
          'quantity': '${newFoodItem.quantity}',
          'purchaseDate': newFoodItem.dateOfPurchase.toString(),
          'expirationDate': newFoodItem.expirationDate.toString(),
          'imageUrl':
              ['imageUrl'],
        });
      });
    }
  }

 Color _getExpirationColor(String expirationDate, String purchaseDate) {
  final expiryDate = DateTime.parse(expirationDate);
  final currentDate = DateTime.now();
  final currentDateAtMidnight = DateTime(currentDate.year, currentDate.month, currentDate.day);
  final purchaseDateParsed = DateTime.parse(purchaseDate);
  final daysLeft = expiryDate.difference(currentDateAtMidnight).inDays;

  // Condition 1: If the expiration date is before the current date.
  if (expiryDate.isBefore(currentDateAtMidnight)) {
    return Color.fromARGB(255, 177, 21, 21);
  } 
  // Condition 2: If the expiration date is before the purchase date.
  else if (expiryDate.isBefore(purchaseDateParsed)) {
    return Color.fromARGB(255, 177, 21, 21);
  }
  else if (daysLeft <= 7) {
    return Colors.yellow;
  } else {
    return Color.fromARGB(255, 20, 220, 27);
  }
}

Widget _nonExpiringBorder(Widget child) {
  return Container(
    decoration: BoxDecoration(
      border: Border.all(color: Color.fromARGB(255, 20, 220, 27), width: 2.0),
      borderRadius: BorderRadius.circular(30),
    ),
    child: child,
  );
}

Widget _closeToExpiringBorder(Widget child) {
  return TweenAnimationBuilder(
    tween: ColorTween(begin: Colors.yellow[700], end: Colors.yellow[300]),
    duration: Duration(seconds: 3),
    builder: (context, color, _) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: color as Color, width: 2.0),
        ),
        child: child,
      );
    },
    onEnd: () {
      // This will ensure the animation keeps cycling
      _closeToExpiringBorder(child);
    },
  );
}
/*Widget _expiredBorder(Widget child) {
  return Container(
    decoration: BoxDecoration(
      border: Border(
        top: BorderSide(color: Color.fromARGB(255, 168, 169, 173), width: 0.8), // Top border
        bottom: BorderSide(color: Color.fromARGB(255, 168, 169, 173), width: 0.8), // Bottom border
        left: BorderSide(color: Color.fromARGB(255, 168, 169, 173), width: 0.8), // Left side border
        right: BorderSide(color: Color.fromARGB(255, 168, 169, 173), width: 0.8), // Right side border
      ),
    ),
    child: child,
  );
}*/
/*Widget _expiredBorder(Widget child) {
  return Container(
    decoration: BoxDecoration(
      border: Border.all(
        color: Color.fromARGB(255, 168, 169, 173),
        width: 0.8,
      ),
      borderRadius: BorderRadius.circular(70), // Add rounded corners
    ),
    child: child,
  );
}*/

Widget _expiredBorder(Widget child) {
  return Container(
    decoration: BoxDecoration(
      border: Border.all(
        color: Color.fromARGB(255, 168, 169, 173),
        width: 0.8,
      ),
      borderRadius: BorderRadius.circular(70), // Rounded corners
    ),
    child: child,
  );
}

Widget _getExpirationBorder(String expirationDate, String purchaseDate, Widget child) {
  final expiryDate = DateTime.parse(expirationDate);
  final currentDate = DateTime.now();
  final purchaseDateParsed = DateTime.parse(purchaseDate);
  final daysLeft = expiryDate.difference(currentDate).inDays;

  // Condition 1: If the expiration date is before the current date.
  if (expiryDate.isBefore(currentDate) || expiryDate.isBefore(purchaseDateParsed)) {
    return _expiredBorder(child);
  }
  // Condition 2: If the expiration date is within 7 days from the current date.
  else if (daysLeft <= 7) {
    return _closeToExpiringBorder(child);
  } else {
    return _nonExpiringBorder(child);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: PreferredSize(
        preferredSize: Size.fromHeight(140.0), // here you can set the desired height
        child: AppBar(
          backgroundColor: Colors.transparent, // Make the AppBar background transparent
          elevation: 0, // Removes the default shadow
         flexibleSpace: Padding( // Apply padding to the flexibleSpace
          padding: const EdgeInsets.symmetric(horizontal: 21.0), // Set horizontal padding
          child: ClipRRect(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)), // Rounded corners at the bottom
            child: Container(
              margin: const EdgeInsets.only(top: 45.0), // Top margin to push AppBar down
              decoration: BoxDecoration(
                color: Color.fromARGB(255, 168, 169, 173), // Your AppBar color
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                border: Border.all(
                  color: const Color.fromARGB(255, 215, 215, 215),
                  width: 2,
                ),
                ),
            ),
          ),
        ),
       shape: RoundedRectangleBorder(

      appBar: AppBar(
        backgroundColor: Color.fromARGB(220, 48, 141, 160),
        elevation: 0, // Removes the default shadow
        shape: RoundedRectangleBorder(

          side: BorderSide(
            color: const Color.fromARGB(253,253,253,253),
             width: 2), // Blue border
        ),
         title: Column(
        mainAxisSize: MainAxisSize.min, // Use min size for the column
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 35.0), // Adjust the padding to move the title down
            child: Center( child: Text('The Fridge Masters'),
          ),
            
          ),
        ],
         ),
         leading: Transform.translate(
        offset: Offset(11, 19), // Add padding to push the icon to the right
        child: IconButton(
          icon: Icon(Icons.notifications),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NotificationList(),
              ),
            );
          },
        ),
         ),
        actions: [
          Transform.translate(
          offset: Offset(-11, 19),
          child:IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => Settings(),
                ),
              );
            },
          ),
          ),
        ],
    
      
    bottom: PreferredSize(
  preferredSize: Size.fromHeight(20),
  child: Padding(
    padding: const EdgeInsets.fromLTRB(50.0, 0.0, 50.0, 10.0), // Reduces bottom padding to 10.0
    child: Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: Colors.white, // Changes the cursor and selection handle color
        ),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: Colors.white, // Changes the cursor color
          selectionColor: Colors.white.withOpacity(0.5), // Changes the selection color
          selectionHandleColor: Colors.white, // Changes the selection handle color
        ),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Filter based on food items',
          border: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white),
            borderRadius: BorderRadius.circular(20),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white),
            borderRadius: BorderRadius.circular(20),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white), // Changes the border color when the TextField is focused
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    ),
  ),
    ),
        ),
      ),
        //prefixIcon: Icon(Icons.search),
      
    
  


        
      

       
      body: Stack(
        children: [
          //const Background(type: 'Background2'),
          Center(
             child: widget.fridgeItems.isEmpty
                  ? Column(
                     mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Add Items to your fridge!'),
                        Icon(Icons.arrow_downward, color: Colors.red),
                      ],
                    )
                  : ListView.builder(

                       itemCount: widget.fridgeItems.length + 1, // +1 for the header (date and legend)

                      itemCount: widget.fridgeItems.length + 1, // +1 for the header (date and legend)
                      

  itemBuilder: (context, index) {
    
    // This is for the header, which contains the date and legend
    if (index == 0) {
      return Column(
  children: [
    SizedBox(height: 10),
    Center(
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: 'Today\'s Date: ',
              style: TextStyle(
                color: Colors.black,
                fontSize: 15,
                fontWeight: FontWeight.bold
              ),
            ),
            TextSpan(
              text:
                  '${DateTime.now().month}/${DateTime.now().day}/${DateTime.now().year}',
              style: TextStyle(
                color: Color.fromARGB(255, 12, 12, 12),
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    ),

   
   // SizedBox(height: 5),
          //Center(
            //child: RichText(
              //textAlign: TextAlign.center,
              //text: TextSpan(
               // children: [
                //  TextSpan(
                  //  text: 'Expiry Legend: ',
                  //  style: TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.bold),
                //  ),
                 // TextSpan(
                  //  text: '🟢Green - Safe to Eat (>1wk) ',
                  //  style: TextStyle(color: Color.fromARGB(255, 4, 114, 8), fontSize: 16, fontWeight: FontWeight.bold), 
                  //),
                 // TextSpan(
                   // text: '| ',
                   // style: TextStyle(color: Color.fromARGB(255, 0, 0, 0), fontSize: 16, fontWeight: FontWeight.bold), 
               //   ),
                 // TextSpan(
                 //   text: '🟡 Yellow - Nearing Expiry (≤1wk) ',
                //    style: TextStyle(color: Color.fromARGB(255, 65, 105, 225), fontSize: 16, fontWeight: FontWeight.bold),
                 // ),
               //   TextSpan(
                //    text: '| ',
                //    style: TextStyle(color: Color.fromARGB(255, 0, 0, 0), fontSize: 16, fontWeight: FontWeight.bold), 
                //  ),
               //   TextSpan(
                //    text: '🔴 Red - Expired',
                 //   style: TextStyle(color: Color.fromARGB(255, 226, 50, 50), fontSize: 16, fontWeight: FontWeight.bold),
                //  ),
              //  ],
         //     ),
        //    ),
              
        //  ),

    SizedBox(height: 5),
          Center(
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Expiry Color Legend: ',
                    style: TextStyle(color: Colors.black, fontSize: 17, fontWeight: FontWeight.bold), 
                  ),
                  TextSpan(
                    text: '🟡',
                    style: TextStyle(color: Color.fromARGB(255, 4, 114, 8), fontSize: 17, fontWeight: FontWeight.bold), 
                  ),
                  TextSpan(
                    text: ' - Safe to Eat (>1wk) | ',
                    style: TextStyle(color: Color.fromARGB(255, 0, 0, 0), fontSize: 16, fontWeight: FontWeight.bold), 
                  ),
                  TextSpan(
                    text: '🟡',
                    style: TextStyle(color: Color.fromARGB(255, 250, 228, 28), fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: ' - Nearing Expiry (≤1wk) | ',
                    style: TextStyle(color: Color.fromARGB(255, 0, 0, 0), fontSize: 16, fontWeight: FontWeight.bold), 
                  ),
                  TextSpan(
                    text: '🟡',
                    style: TextStyle(color: Color.fromARGB(255, 226, 50, 50), fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: ' - Expired',
                    style: TextStyle(color: Color.fromARGB(255, 0, 0, 0), fontSize: 16, fontWeight: FontWeight.bold), 
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 10),
        ],
      );
    } else {
      // Index is greater than 0, so it's an item
                        final item = widget.fridgeItems[index-1];


                        //Color _getPastelColor(int index) {

                         Color _getLightGrayColor() {
  // Light gray color #F0F0F0
  return Color.fromRGBO(240, 240, 240, 1); // Opacity is set to 1 for a solid color
}





                         //// final r = (70 + (index * 50) % 135).toDouble();
                          //final g = (90 + (index * 80) % 85).toDouble();
                        ///  final b = (120 + (index * 30) % 55).toDouble();
                          //return Color.fromRGBO(
                             // r.toInt(), g.toInt(), b.toInt(), 0.9);
                        //}

                        return Padding(
                          padding: const EdgeInsets.all(8.0),
  child: Card(
    //color: _getPastelColor(index),
    color: _getLightGrayColor(),
    elevation: 4.0,
   shape: RoundedRectangleBorder(
  side: BorderSide(
    color: Color.fromARGB(255, 168, 169, 173), // Same color
    width: 0.8, // Same width
  ),
  borderRadius: BorderRadius.circular(70), // Same rounded corners as in _expiredBorder
),

   /*shape: RoundedRectangleBorder(
      
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(900.0),
        topRight: Radius.circular(900.0),
        bottomLeft: Radius.circular(900.0),
        bottomRight: Radius.circular(900.0),
      ),
    ),*/
                            
   child: SizedBox(
    height: 200, // Add your desired height here
    // Your card content goes here 
  
        
  
                        
                                      
                            child: _getExpirationBorder(
  item['expirationDate'], 
  item['purchaseDate'],Container(

                        final itemId = item['itemId'];
                        //print('Item ID at index $index: $itemId');
                        Color _getPastelColor(int index) {
                          final r = (70 + (index * 50) % 135).toDouble();
                          final g = (90 + (index * 80) % 85).toDouble();
                          final b = (120 + (index * 30) % 55).toDouble();
                          return Color.fromRGBO(
                              r.toInt(), g.toInt(), b.toInt(), 0.9);
                        }

                     ImageProvider getImageProvider(String? imageUrl) {
  // Check if imageUrl is a network URL
  if (imageUrl != null && Uri.tryParse(imageUrl)?.hasAbsolutePath == true) {
    // If it's a valid URL, return a NetworkImage
    return NetworkImage(imageUrl);
  } else {
    // If it's not a valid URL (or is null), return a AssetImage
    return AssetImage('images/default_image.png');
  }
}  
                           return Padding(
  padding: const EdgeInsets.all(8.0),
  child: Card(
    color: _getPastelColor(index),
    elevation: 4.0, // Added shadow
    child:  ExpiringItemTile(
      expirationDate: item['expirationDate'],
      purchaseDate: item['purchaseDate'],
      child: Container(

                              height: 137,
                              child: Stack(
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(

                                        flex: 3,
                                        child: Padding(
                                          padding: const EdgeInsets.all(
                                              16.0), // Image padding
                                          child: Container(
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                  color: const Color.fromARGB(255, 221, 145, 117),
                                                  width: 3),
                                              image: DecorationImage(
                                                image: NetworkImage(item[
                                                        'imageUrl'] ??
                                                    'images/default_image.png'), // Explicit Null Check for imageUrl
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                            width: 100,
                                            height: 100,
                                          ),
                                        ),
                                      ),

  flex: 3,
  child: Padding(
    padding: const EdgeInsets.all(16.0), // Image padding
    child: Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.brown, width: 3),
      ),
      width: 100,
      height: 100,
      child: Image.network(
        item['imageUrl'].toString() ?? '',
        fit: BoxFit.cover,
        errorBuilder: (BuildContext context, Object exception, StackTrace? stackTrace) {
          // In case of an error (like a 404), use the default image
          return Image.asset('images/default_image.png', fit: BoxFit.cover);
        },
        loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
      ),
    ),
  ),
),

                                      Expanded(
                                        flex: 7,
                                        child: Column(
                                          children: [
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Center(
                                                      child: RichText(
                                                        textAlign:
                                                            TextAlign.center,
                                                        text: TextSpan(
                                                          style: DefaultTextStyle
                                                                  .of(context)
                                                              .style,
                                                          children: <TextSpan>[
                                                            TextSpan(
                                                                text: 'Name: ',
                                                                style: TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .normal,
                                                                    fontSize:
                                                                        12)), // Descriptor size
                                                            TextSpan(
                                                                text:
                                                                    '${item['name']}',
                                                                style: TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        18,
                                                                       color: Colors.black,
                                                                ),
                                                            ),
                                                                   // color: Color.fromARGB(0, 0, 0, 0),decoration: TextDecoration.underline)), // User-entered text size
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Center(
                                                      child: RichText(
                                                        text: TextSpan(
                                                          style: DefaultTextStyle
                                                                  .of(context)
                                                              .style,
                                                          children: <TextSpan>[
                                                            TextSpan(
                                                                text:
                                                                    'Purchased: ',
                                                                style: TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .normal)),
                                                            TextSpan(
                                                                text: convertToDisplayFormat(
                                                                    item[
                                                                        'purchaseDate']),
                                                                style: TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:

                                                                        17,
                                                              color: Colors.black,

                                                                   /* color: Color

                                                                        16,
                                                                    color: Color

                                                                        .fromARGB(
                                                                            255,
                                                                            255,
                                                                            255,
                                                                            255)*/)),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Center(
                                                      child: RichText(
                                                        text: TextSpan(
                                                          style: DefaultTextStyle
                                                                  .of(context)
                                                              .style,
                                                          children: <TextSpan>[
                                                            TextSpan(
                                                                text: 'Qty: ',
                                                                style: TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .normal)),
                                                            TextSpan(
                                                                text:
                                                                    '${item['quantity']}',
                                                                style: TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:

                                                                        17.5,
                                                                        color: Colors.black,
                                                                   /* color: Color

                                                                        15.5,
                                                                    color: Color

                                                                        .fromARGB(
                                                                            255,
                                                                            255,
                                                                            255,
                                                                            255)*/)),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Center(
                                                      child: RichText(
                                                        text: TextSpan(
                                                          style: DefaultTextStyle
                                                                  .of(context)
                                                              .style,
                                                          children: <TextSpan>[
                                                            TextSpan(
                                                                text:
                                                                    'Expiry: ',
                                                                style: TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .normal)),
                                                            TextSpan(
                                                              text: convertToDisplayFormat(
                                                                  item[
                                                                      'expirationDate']),
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 17,
                                                                color: _getExpirationColor(item['expirationDate'], item['purchaseDate'])

                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                 /* Positioned(
                                    bottom: 5, // adjust as needed
                                    left: 30, // adjust as needed

                                  Positioned(
                                    bottom: 1, // adjust as needed
                                    left: 38, // adjust as needed

                                    child: Text(
                                      '    Click Image for\nNutritional Insights!', // replace with dynamic data if needed
                                      style: TextStyle(
                                        fontSize: 8,
                                        color: Color.fromARGB(255, 255, 255,
                                            255), // or any color you prefer
                                      ),
                                    ),

                                  ),*/
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                ),
                                   Positioned(
                                    top: -5,
                                    right: -5,

                                    child: IconButton(
                                      icon: Icon(Icons.delete, size: 18),
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (BuildContext context) {
                                            bool isChecked = false;
                                            return AlertDialog(
                                              title: Text('Delete Item'),
                                              content: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                      'Are you sure you want to delete this item?'),
                                                  Row(
                                                    children: [
                                                      Checkbox(
                                                        value: isChecked,
                                                        onChanged:
                                                            (bool? value) {
                                                          setState(() {
                                                            isChecked = value!;
                                                          });
                                                        },
                                                      ),
                                                      Text("This has expired"),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Remove this line
            },
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final currentItem = widget.fridgeItems[index-1];
              try {
                final StorageService storageService = StorageService();
                String? userID = await storageService.getStoredUserId();
                
                 if (userID != null) {
    String itemIdString = itemId.toString();
    await deleteItem(userID, itemIdString);
                  
                  // If the deletion was successful in the backend, remove from the local list
                  setState(() {
                    widget.fridgeItems.removeAt(index - 1); // Adjust index
                  });
                }
              } catch (e) {
                // Handle any exceptions that might occur during the deletion
                print('Error deleting item: $e');
              }
              
              Navigator.of(context).pop(); // Keep this line to close the dialog
            },
            child: Text('Delete'),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )

                          ),
                        ));

                           )
                         );
    }

                      },
          )),
          
      
        ],
      ),
      bottomNavigationBar: Taskbar(
        currentIndex: 0,
        backgroundColor: Color.fromARGB(255, 233, 232, 232),
        onTabChanged: (index) {},
        onFoodItemAdded: (foodItem) {
          // You need to provide this callback
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddItem,
        child: Icon(Icons.add),
        backgroundColor: Color.fromARGB(168, 169, 173, 226),
      ),
     
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

       
    );
     
  }
}


