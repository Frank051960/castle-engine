/* -*- tab-width: 4 -*- */
package net.sourceforge.castleengine;

import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.provider.MediaStore;
import android.util.Log;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;

public class ServiceOpenAssociatedUrls extends ServiceAbstract
{
    private static final String TAG = "${NAME}.castleengine.ServiceOpenAssociatedUrls";

    public String getName()
    {
        return "open_associated_urls";
    }

    public ServiceOpenAssociatedUrls(MainActivity activity)
    {
        super(activity);
    }

    @Override
    public void onCreate()
    {
        Intent intent = getActivity().getIntent();
        openIntent(intent);
    }

    @Override
    public void onNewIntent(Intent intent)
    {
        openIntent(intent);
    }

    private void openIntent(Intent intent)
    {
        // https://stackoverflow.com/a/26034600/2870459
        String action = intent.getAction();
        if (action != null && action.compareTo(Intent.ACTION_VIEW) == 0)
        {
            String scheme = intent.getScheme();
            Uri uri = intent.getData();
            if (scheme == null || uri == null)
                return;

            ContentResolver resolver = getActivity().getContentResolver();

            File urlDocumentsDir = getActivity().getDir("inbox", Context.MODE_PRIVATE);

            if (scheme.compareTo(ContentResolver.SCHEME_CONTENT) == 0)
            {
                String name = getContentName(resolver, uri);

                Log.i(TAG, "Content intent detected: " + action + " : " + intent.getDataString() + " : " + intent.getType() + " : " + name);
                try
                {
                    InputStream input = resolver.openInputStream(uri);
                    String importfilepath = urlDocumentsDir.getAbsolutePath() + "/" + name;
                    InputStreamToFile(input, importfilepath);
                    messageSend(new String[]{"open_associated_url", "file://" + importfilepath});
                }
                catch (Exception e)
                {
                    Log.e(TAG, "resolver.openInputStream exception: " + e.getMessage());
                }
            }
            else if (scheme.compareTo(ContentResolver.SCHEME_FILE) == 0)
            {
                String name = uri.getLastPathSegment();

                Log.i(TAG, "File intent detected: " + action + " : " + intent.getDataString() + " : " + intent.getType() + " : " + name);
                messageSend(new String[]{"open_associated_url", uri.toString()});
            }
            else if (scheme.compareTo("http") == 0 || scheme.compareTo("https") == 0 || scheme.compareTo("ftp") == 0)
            {
                String name = uri.getLastPathSegment();

                Log.i(TAG, "Http intent detected: " + action + " : " + intent.getDataString() + " : " + intent.getType() + " : " + name);
                // open directly from http, let it download in CastleDownload.pas
                messageSend(new String[]{"open_associated_url", uri.toString()});
            }
        }
    }

    private String getContentName(ContentResolver resolver, Uri uri)
    {
        String sName = "untitled";
        Cursor cursor = resolver.query(uri, null, null, null, null);
        if (cursor != null)
        {
            cursor.moveToFirst();
            int nameIndex = cursor.getColumnIndex(MediaStore.MediaColumns.DISPLAY_NAME);
            if (nameIndex >= 0)
                sName = cursor.getString(nameIndex);
            cursor.close();
        }
        return sName;
    }

    private void InputStreamToFile(InputStream in, String file)
    {
        try
        {
            OutputStream out = new FileOutputStream(new File(file));

            int size = 0;
            byte[] buffer = new byte[1024];

            while ((size = in.read(buffer)) != -1)
            {
                out.write(buffer, 0, size);
            }

            out.close();
        }
        catch (Exception e)
        {
            Log.e(TAG, "InputStreamToFile exception: " + e.getMessage());
        }
    }
}
